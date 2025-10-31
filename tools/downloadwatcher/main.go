package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/atotto/clipboard"
	"github.com/fsnotify/fsnotify"
)

var (
	dir        = flag.String("dir", os.Getenv("HOME")+"/Downloads", "Directory to watch")
	script    = flag.String("script", "/Users/agribko/scripts/utility/process_download.sh", "First script")
	minSize    = flag.Int64("minsize", 1<<10, "Minimum size (bytes) to consider file 'real'")
	quietDelay = flag.Duration("settle", 750*time.Millisecond, "Delay to let file settle before processing")
)

func parseClipboard() (ticket, filename string) {
	txt, err := clipboard.ReadAll()
	if err != nil {
		return "", ""
	}
	txt = strings.TrimSpace(txt)
	if txt == "" {
		return "", ""
	}
	// Expect "ticket filename.ext"; split at first space
	parts := strings.SplitN(txt, " ", 2)
	if len(parts) == 2 {
		return parts[0], strings.TrimSpace(parts[1])
	}
	return "", txt
}

func shouldIgnore(name string) bool {
	l := strings.ToLower(name)
	return strings.HasSuffix(l, ".crdownload") || strings.HasSuffix(l, ".download") || strings.HasPrefix(filepath.Base(l), ".")
}

func runScripts(path, ticket string) error {
 base := filepath.Base(path)

    // script1 ticket + filename
    if _, err := os.Stat(*script); err == nil {
        if err := exec.Command("/bin/zsh", *script, ticket, base).Run(); err != nil {
            return fmt.Errorf("script: %w", err)
        }
    }
    return nil
}

func main() {
	flag.Parse()

	w, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer w.Close()

	if err := w.Add(*dir); err != nil {
		log.Fatalf("watch add: %v", err)
	}
	log.Printf("Watching %s", *dir)

	processed := make(map[string]struct{})

	for {
		select {
		case ev := <-w.Events:
			if ev.Op&(fsnotify.Create|fsnotify.Rename|fsnotify.Write) == 0 {
				continue
			}
			path := ev.Name
			name := filepath.Base(path)
			if shouldIgnore(name) {
				continue
			}
			// Avoid duplicate work
			if _, ok := processed[path]; ok {
				continue
			}
			// Let the file settle (finish writing/renaming)
			go func(p, base string) {
				time.Sleep(*quietDelay)
				fi, err := os.Stat(p)
				if err != nil || fi.IsDir() || fi.Size() < *minSize {
					return
				}
				ticket, expect := parseClipboard()
				if expect != "" && base != expect {
					// Not the file we care about; skip
					return
				}
				log.Printf("Processing %s (ticket=%s)", base, ticket)
				if err := runScripts(p, ticket); err != nil {
					log.Printf("ERROR: %v", err)
					return
				}
				processed[p] = struct{}{}
			}(path, name)

		case err := <-w.Errors:
			log.Printf("watch error: %v", err)
		}
	}
}
