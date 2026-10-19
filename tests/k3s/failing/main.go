// Command failing is a guest test binary that always reports one failing
// pass_condition, so //tests/k3s:k3s_failing_pc_fails_test can assert that
// firecracker_k3s_test turns it into a test failure.
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	report := flag.String("report-json", "/tmp/report.json", "report output")
	// Never read: the launcher passes every test binary these flags, and
	// flag.Parse exits 2 on an undefined one before any report is written.
	flag.String("scenario", "", "accepted for the launcher's flag contract; unused")
	flag.String("kubeconfig", "", "accepted for the launcher's flag contract; unused")
	flag.String("namespace", "", "accepted for the launcher's flag contract; unused")
	flag.Parse()
	if err := os.WriteFile(*report, []byte(`{"scenario":"failing","pass_conditions":[`+
		`{"id":"ok.pc","label":"ok","passed":true},`+
		`{"id":"deliberate.failure","label":"deliberate","passed":false,"error":"this PC always fails"}]}`), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "write report:", err)
	}
	os.Exit(1)
}
