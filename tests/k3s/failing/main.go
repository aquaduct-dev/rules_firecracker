// Command failing is a guest test binary that always reports one failing
// pass_condition, so //tests/k3s:k3s_failing_pc_fails_test can assert that
// firecracker_k3s_test turns it into a test failure.
package main

import (
	"flag"
	"os"
)

func main() {
	report := flag.String("report-json", "/tmp/report.json", "report output")
	flag.String("scenario", "", "")
	flag.String("kubeconfig", "", "")
	flag.String("namespace", "", "")
	flag.Parse()
	os.WriteFile(*report, []byte(`{"scenario":"failing","pass_conditions":[`+
		`{"id":"ok.pc","label":"ok","passed":true},`+
		`{"id":"deliberate.failure","label":"deliberate","passed":false,"error":"this PC always fails"}]}`), 0o644)
	os.Exit(1)
}
