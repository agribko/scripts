// unlink-tags-go bulk-unlinks BLE tags from vehicles via the CMT Station API.
//
// It reads two CSV inputs:
//   1. A target list of tag MAC addresses to unlink.
//   2. A full export of current tag-vehicle mappings (from chartdata).
//
// It cross-references the two lists, then sends batched API requests using a
// concurrent worker pool to set tag_mac_address=null for matched vehicles.
package main

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"
)

// macRegex validates lowercase colon-separated MAC addresses (e.g. "aa:bb:cc:dd:ee:ff").
var macRegex = regexp.MustCompile(`^[a-f0-9]{2}:[a-f0-9]{2}:[a-f0-9]{2}:[a-f0-9]{2}:[a-f0-9]{2}:[a-f0-9]{2}$`)

// Config holds all CLI flags and resolved settings for a single run.
type Config struct {
	TargetCSV  string // Path to CSV containing MACs to unlink
	AllTagsCSV string // Path to full tag-vehicle mapping export
	DryRun     bool   // If true, print payloads without calling the API
	BatchSize  int    // Number of vehicles per API request
	Workers    int    // Number of concurrent goroutines sending requests
	OPItem     string // 1Password item name for credential lookup
	Hostname   string // API hostname (e.g. "api.example.com")
	APIKey     string // API authentication key
}

// Vehicle represents a vehicle-tag association in the API payload.
// TagMacAddress is a pointer so it serializes to JSON null when unlinking.
type Vehicle struct {
	ShortVehicleID string  `json:"short_vehicle_id"`
	TagMacAddress  *string `json:"tag_mac_address"`
}

// UpdatePayload is the JSON body sent to the update_users_and_vehicles endpoint.
type UpdatePayload struct {
	Vehicles []Vehicle `json:"vehicles"`
}

// BatchResult captures the outcome of a single batch API call for reporting.
type BatchResult struct {
	Index      int    // Zero-based batch index for log correlation
	Success    bool   // True if the API returned 2xx
	StatusCode int    // HTTP status code (0 if request failed entirely)
	Error      error  // Network or marshal error
	Body       string // Response body on non-retryable failures
}

func main() {
	cfg := parseFlags()

	// Set up dual logging: stdout for interactive use, file for audit trail.
	logFile := setupLogFile()
	defer logFile.Close()
	logger := log.New(io.MultiWriter(os.Stdout, logFile), "", log.LstdFlags)

	// Resolve API credentials from flags, 1Password, or environment (in that priority order).
	apiKey, hostname := resolveCredentials(cfg, logger)

	// Step 1: Load the set of MAC addresses we want to unlink.
	logger.Println("reading target tag MACs")
	targetMACs, err := readTargetMACs(cfg.TargetCSV, logger)
	if err != nil {
		logger.Fatalf("failed to read target CSV: %v", err)
	}
	logger.Printf("loaded %d target MACs", len(targetMACs))

	// Step 2: Load the full tag-vehicle mapping to find which vehicles own these MACs.
	logger.Println("reading all-tags CSV (chartdata)")
	allTags, err := readAllTagsCSV(cfg.AllTagsCSV)
	if err != nil {
		logger.Fatalf("failed to read all-tags CSV: %v", err)
	}
	logger.Printf("loaded %d linked vehicles from all-tags", len(allTags))

	// Step 3: Cross-reference to find vehicles that need unlinking.
	toUnlink := filterVehiclesToUnlink(targetMACs, allTags)
	logger.Printf("matched %d vehicles to unlink", len(toUnlink))

	if len(toUnlink) == 0 {
		logger.Println("no vehicles to unlink — nothing to do")
		return
	}

	// Step 4: Send batched unlink requests via concurrent worker pool.
	unlinkVehicles(toUnlink, apiKey, hostname, cfg, logger)
	logger.Println("done")
}

// parseFlags parses CLI arguments and validates required inputs.
func parseFlags() Config {
	cfg := Config{}
	flag.StringVar(&cfg.TargetCSV, "target-csv", "", "file with tag_mac_address values to unlink (required)")
	flag.StringVar(&cfg.AllTagsCSV, "all-tags-csv", "", "CSV with current vehicle-tag mappings: tag_mac_address, short_vehicle_id (required)")
	flag.BoolVar(&cfg.DryRun, "dry-run", false, "simulate without making API calls")
	flag.IntVar(&cfg.BatchSize, "batch-size", 5, "vehicles per API request")
	flag.IntVar(&cfg.Workers, "workers", 10, "concurrent API workers")
	flag.StringVar(&cfg.OPItem, "op-item", "", "1Password item name containing 'hostname' and 'api-key' fields")
	flag.StringVar(&cfg.Hostname, "hostname", "", "API hostname (overrides op/env)")
	flag.StringVar(&cfg.APIKey, "api-key", "", "API key (overrides op/env)")
	flag.Parse()

	if cfg.TargetCSV == "" || cfg.AllTagsCSV == "" {
		fmt.Fprintf(os.Stderr, "Usage: unlink-tags-go --target-csv <file> --all-tags-csv <file> [options]\n\n")
		fmt.Fprintf(os.Stderr, "Credential resolution order:\n")
		fmt.Fprintf(os.Stderr, "  1. --hostname / --api-key flags\n")
		fmt.Fprintf(os.Stderr, "  2. --op-item <name> (reads from 1Password CLI)\n")
		fmt.Fprintf(os.Stderr, "  3. CMT_HOSTNAME / CMT_API_KEY environment variables\n\n")
		flag.PrintDefaults()
		os.Exit(1)
	}
	return cfg
}

// resolveCredentials determines API credentials using a priority chain:
// explicit flags > 1Password CLI > environment variables.
func resolveCredentials(cfg Config, logger *log.Logger) (apiKey, hostname string) {
	if cfg.APIKey != "" && cfg.Hostname != "" {
		logger.Println("using credentials from flags")
		return cfg.APIKey, cfg.Hostname
	}

	if cfg.OPItem != "" {
		logger.Printf("fetching credentials from 1Password item %q", cfg.OPItem)
		hostname, apiKey = opGetItem(cfg.OPItem)
		if hostname == "" || apiKey == "" {
			logger.Fatal("failed to read hostname or credential from 1Password item")
		}
		return apiKey, hostname
	}

	hostname = os.Getenv("CMT_HOSTNAME")
	apiKey = os.Getenv("CMT_API_KEY")
	if hostname != "" && apiKey != "" {
		logger.Println("using credentials from environment variables")
		return apiKey, hostname
	}

	logger.Fatal("no credentials provided: use --api-key/--hostname, --op-item, or set CMT_HOSTNAME/CMT_API_KEY")
	return
}

// opGetItem fetches credentials from a 1Password item using "op item get --reveal --format json"
// and extracts the "hostname" and "credential" fields by label.
func opGetItem(item string) (hostname, apiKey string) {
	out, err := exec.Command("op", "item", "get", item, "--reveal", "--format", "json").Output()
	if err != nil {
		return "", ""
	}

	var parsed struct {
		Fields []struct {
			Label string `json:"label"`
			Value string `json:"value"`
		} `json:"fields"`
	}
	if err := json.Unmarshal(out, &parsed); err != nil {
		return "", ""
	}

	for _, f := range parsed.Fields {
		switch f.Label {
		case "hostname":
			hostname = f.Value
		case "credential":
			apiKey = f.Value
		}
	}
	return hostname, apiKey
}

// setupLogFile creates a timestamped log file in the current directory for audit purposes.
func setupLogFile() *os.File {
	name := fmt.Sprintf("unlink_tags_%s.log", time.Now().Format("20060102150405"))
	f, err := os.Create(name)
	if err != nil {
		log.Fatalf("cannot create log file: %v", err)
	}
	return f
}

// readTargetMACs reads a single-column CSV of tag MAC addresses to unlink.
// Supports both headerless files and files with a "tag_mac_address" header row.
// Returns a set (map) for O(1) lookups during filtering.
func readTargetMACs(path string, logger *log.Logger) (map[string]bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.LazyQuotes = true
	r.TrimLeadingSpace = true
	r.FieldsPerRecord = -1 // Allow variable column counts

	allRows, err := r.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("reading file: %w", err)
	}

	result := make(map[string]bool, len(allRows))
	var unmatched []string
	startIdx := 0

	// Skip header row if present.
	if len(allRows) > 0 && strings.TrimSpace(strings.ToLower(allRows[0][0])) == "tag_mac_address" {
		startIdx = 1
	}

	for _, row := range allRows[startIdx:] {
		if len(row) == 0 {
			continue
		}
		mac := strings.TrimSpace(strings.ToLower(row[0]))
		if mac == "" {
			continue
		}
		if macRegex.MatchString(mac) {
			result[mac] = true
		} else {
			unmatched = append(unmatched, row[0])
		}
	}

	if len(unmatched) > 0 {
		logger.Printf("WARNING: %d rows skipped (invalid MAC format): %v", len(unmatched), unmatched)
	}
	return result, nil
}

// readAllTagsCSV reads the chartdata export containing all current tag-vehicle links.
// It dynamically locates tag_mac_address and short_vehicle_id columns by header name.
func readAllTagsCSV(path string) ([]Vehicle, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.LazyQuotes = true
	r.TrimLeadingSpace = true

	// Parse header to find required column indices.
	header, err := r.Read()
	if err != nil {
		return nil, fmt.Errorf("reading header: %w", err)
	}
	for i := range header {
		header[i] = strings.TrimSpace(strings.ToLower(header[i]))
	}

	macCol := slices.Index(header, "tag_mac_address")
	vidCol := slices.Index(header, "short_vehicle_id")
	if macCol < 0 || vidCol < 0 {
		return nil, fmt.Errorf("required columns 'tag_mac_address' and 'short_vehicle_id' not found")
	}

	records, err := r.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("reading CSV body: %w", err)
	}

	vehicles := make([]Vehicle, 0, len(records))
	for _, row := range records {
		if macCol >= len(row) || vidCol >= len(row) {
			continue
		}
		mac := strings.TrimSpace(strings.ToLower(row[macCol]))
		vid := strings.TrimSpace(row[vidCol])
		if mac == "" || vid == "" {
			continue
		}
		vehicles = append(vehicles, Vehicle{ShortVehicleID: vid, TagMacAddress: &mac})
	}
	return vehicles, nil
}

// filterVehiclesToUnlink returns vehicles whose tag MAC is in the target set.
// Deduplicates by MAC address so each tag is unlinked only once.
func filterVehiclesToUnlink(targetMACs map[string]bool, allTags []Vehicle) []Vehicle {
	var result []Vehicle
	seen := make(map[string]bool)
	for _, v := range allTags {
		if v.TagMacAddress == nil {
			continue
		}
		mac := *v.TagMacAddress
		if targetMACs[mac] && !seen[mac] {
			seen[mac] = true
			result = append(result, v)
		}
	}
	return result
}

// unlinkVehicles orchestrates the concurrent batch unlinking process.
// It splits vehicles into batches, fans them out to a worker pool via channels,
// and collects results for logging.
func unlinkVehicles(vehicles []Vehicle, apiKey, hostname string, cfg Config, logger *log.Logger) {
	batches := makeBatches(vehicles, cfg.BatchSize)
	logger.Printf("processing %d vehicles in %d batches (%d workers)", len(vehicles), len(batches), cfg.Workers)

	if cfg.DryRun {
		logger.Println("[DRY RUN] would send the following batches:")
		for i, batch := range batches {
			data, _ := json.Marshal(buildPayload(batch))
			logger.Printf("  batch %d: %s", i+1, string(data))
		}
		return
	}

	// results collects outcomes from workers; buffered to avoid blocking goroutines.
	results := make(chan BatchResult, len(batches))

	// work is a channel of batch indices; workers pull from it until closed.
	work := make(chan int, len(batches))

	// Spawn worker goroutines. Each worker has its own HTTP client to avoid
	// connection contention and processes batches until the work channel is drained.
	var wg sync.WaitGroup
	for range cfg.Workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			client := &http.Client{Timeout: 40 * time.Second}
			for i := range work {
				results <- sendBatch(client, batches[i], apiKey, hostname, i)
			}
		}()
	}

	// Enqueue all batch indices, then close the channel to signal workers to exit.
	for i := range batches {
		work <- i
	}
	close(work)

	// Close results channel once all workers finish so the range loop below terminates.
	go func() {
		wg.Wait()
		close(results)
	}()

	// Collect and log results as they arrive.
	var successCount, failCount int
	for r := range results {
		if r.Success {
			successCount++
			logger.Printf("batch %d: success (HTTP %d)", r.Index+1, r.StatusCode)
		} else {
			failCount++
			if r.Error != nil {
				logger.Printf("batch %d: FAILED error=%v", r.Index+1, r.Error)
			} else {
				logger.Printf("batch %d: FAILED HTTP %d body=%s", r.Index+1, r.StatusCode, r.Body)
			}
		}
	}

	logger.Printf("complete: %d succeeded, %d failed (out of %d batches)", successCount, failCount, len(batches))
}

// sendBatch POSTs a single batch to the API with up to 3 retry attempts.
// Retries only on transient server errors (500, 502, 504) with linear backoff.
// Non-retryable errors (4xx) return immediately.
func sendBatch(client *http.Client, batch []Vehicle, apiKey, hostname string, index int) BatchResult {
	data, err := json.Marshal(buildPayload(batch))
	if err != nil {
		return BatchResult{Index: index, Error: err}
	}

	url := fmt.Sprintf("https://%s/station/v4/update_users_and_vehicles", hostname)

	var lastErr error
	for attempt := range 3 {
		// Linear backoff: 0s, 1s, 2s.
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * time.Second)
		}

		req, err := http.NewRequest("POST", url, bytes.NewReader(data))
		if err != nil {
			return BatchResult{Index: index, Error: err}
		}
		req.Header.Set("X-Cmt-Api-Key", apiKey)
		req.Header.Set("Content-Type", "application/json")

		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue // Network error — retry
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			return BatchResult{Index: index, Success: true, StatusCode: resp.StatusCode}
		}

		// Retry on transient server errors only.
		if resp.StatusCode == 500 || resp.StatusCode == 502 || resp.StatusCode == 504 {
			lastErr = fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
			continue
		}

		// Non-retryable client error (e.g. 400, 401, 403) — fail immediately.
		return BatchResult{Index: index, StatusCode: resp.StatusCode, Body: string(body)}
	}

	return BatchResult{Index: index, Error: lastErr}
}

// buildPayload creates the API request body, setting TagMacAddress to nil (JSON null)
// for each vehicle to unlink the tag.
func buildPayload(batch []Vehicle) UpdatePayload {
	vehicles := make([]Vehicle, len(batch))
	for i, v := range batch {
		vehicles[i] = Vehicle{ShortVehicleID: v.ShortVehicleID, TagMacAddress: nil}
	}
	return UpdatePayload{Vehicles: vehicles}
}

// makeBatches splits a slice into chunks of the given size.
func makeBatches(items []Vehicle, size int) [][]Vehicle {
	batches := make([][]Vehicle, 0, (len(items)+size-1)/size)
	for i := 0; i < len(items); i += size {
		batches = append(batches, items[i:min(i+size, len(items))])
	}
	return batches
}
