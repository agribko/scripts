package main

import (
	"fmt"
	"net/http"
	"log/slog"
)

func main() {
	client := &http.Client{}
	logger := slog.Default()
	url := "https://httpbin.org/post" 
	req, err := http.NewRequest("POST",url,nil)
	if err != nil {
		fmt.Printf("Error building request %v\n", err)
	}

	req.Header.Set("accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("Error calling the API %v\n", err)
	}

	fmt.Printf("API call completed.")
	resp.Body.Close()
}
