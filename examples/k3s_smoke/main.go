// Command k3s_smoke is the guest-side test binary for the
// firecracker_k3s_test smoke target. It runs INSIDE the microVM after
// k3s has been started by /sbin/init and asserts that:
//
//  1. The kubeconfig at /etc/rancher/k3s/k3s.yaml is readable.
//  2. `k3s kubectl get nodes -o json` reports at least one node with
//     status.conditions[Ready]=True.
//
// On pass it writes a lib/clusterharness.Report with a single PC
// `boot.k3s-ready` passed=true. On failure it writes a PC with the
// failure reason as `error`.
//
// The binary is statically linked (cgo-free Go) so it can live on the
// busybox-only rootfs.
package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"time"
)

type reportPC struct {
	ID     string `json:"id"`
	Label  string `json:"label"`
	Passed bool   `json:"passed"`
	Error  string `json:"error,omitempty"`
}

type report struct {
	Scenario       string     `json:"scenario"`
	PassConditions []reportPC `json:"pass_conditions"`
}

func main() {
	var scenarioPath, reportPath, kubeconfig, namespace string
	flag.StringVar(&scenarioPath, "scenario", "", "scenario YAML path (unused for smoke)")
	flag.StringVar(&reportPath, "report-json", "/tmp/report.json", "report JSON output path")
	flag.StringVar(&kubeconfig, "kubeconfig", "/etc/rancher/k3s/k3s.yaml", "kubeconfig path")
	flag.StringVar(&namespace, "namespace", "default", "namespace (unused)")
	flag.Parse()
	_ = scenarioPath
	_ = namespace

	rep := report{Scenario: "k3s_smoke"}

	if _, err := os.Stat(kubeconfig); err != nil {
		rep.PassConditions = append(rep.PassConditions, reportPC{
			ID: "boot.kubeconfig", Label: "kubeconfig-present", Passed: false,
			Error: fmt.Sprintf("kubeconfig stat: %v", err),
		})
		finish(reportPath, rep, 1)
	}
	rep.PassConditions = append(rep.PassConditions, reportPC{
		ID: "boot.kubeconfig", Label: "kubeconfig-present", Passed: true,
	})

	if err := waitNodeReady(kubeconfig, 60*time.Second); err != nil {
		rep.PassConditions = append(rep.PassConditions, reportPC{
			ID: "boot.k3s-ready", Label: "k3s-ready", Passed: false,
			Error: err.Error(),
		})
		finish(reportPath, rep, 1)
	}
	rep.PassConditions = append(rep.PassConditions, reportPC{
		ID: "boot.k3s-ready", Label: "k3s-ready", Passed: true,
	})

	finish(reportPath, rep, 0)
}

// finish writes the report and exits with code. The report is how the host
// learns why the guest failed, so failing to write it is itself a failure:
// a passing run still exits non-zero, and the reason goes to the console.
func finish(path string, r report, code int) {
	if err := writeReport(path, r); err != nil {
		fmt.Fprintf(os.Stderr, "k3s_smoke: report not written, host gets no pass_conditions: %v\n", err)
		os.Exit(1)
	}
	os.Exit(code)
}

// waitNodeReady polls until a node reports Ready. On timeout the error says
// which of the two ways it failed — kubectl never answering (API server
// down) or answering with no Ready node — and how often each happened,
// since the last attempt alone does not tell them apart.
func waitNodeReady(kubeconfig string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	var lastCmdErr, lastState string
	cmdFails, notReady := 0, 0
	for attempt := 1; time.Now().Before(deadline); attempt++ {
		cmd := exec.Command("/usr/local/bin/k3s", "kubectl",
			"--kubeconfig="+kubeconfig,
			"get", "nodes",
			"-o", "jsonpath={range .items[*]}{.metadata.name}{\"\\t\"}{.status.conditions[?(@.type=='Ready')].status}{\"\\n\"}{end}")
		out, err := cmd.CombinedOutput()
		switch {
		case err != nil:
			cmdFails++
			lastCmdErr = fmt.Sprintf("%v: %s", err, out)
			fmt.Fprintf(os.Stderr, "k3s_smoke: attempt %d: kubectl get nodes failed: %s\n", attempt, lastCmdErr)
		case hasReady(string(out)):
			fmt.Fprintf(os.Stderr, "k3s_smoke: attempt %d: node Ready\n", attempt)
			return nil
		default:
			notReady++
			lastState = fmt.Sprintf("%q", string(out))
			fmt.Fprintf(os.Stderr, "k3s_smoke: attempt %d: no Ready node yet: %s\n", attempt, lastState)
		}
		time.Sleep(2 * time.Second)
	}
	msg := fmt.Sprintf("no Ready node after %v (%d kubectl failures, %d not-ready answers)", timeout, cmdFails, notReady)
	if lastState != "" {
		msg += "; last nodes: " + lastState
	}
	if lastCmdErr != "" {
		msg += "; last kubectl error: " + lastCmdErr
	}
	return errors.New(msg)
}

func hasReady(out string) bool {
	for _, line := range splitLines(out) {
		// Format: "<name>\tTrue" or "<name>\tFalse"
		for i := 0; i < len(line); i++ {
			if line[i] == '\t' {
				if line[i+1:] == "True" {
					return true
				}
				break
			}
		}
	}
	return false
}

func splitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			if i > start {
				out = append(out, s[start:i])
			}
			start = i + 1
		}
	}
	if start < len(s) {
		out = append(out, s[start:])
	}
	return out
}

func writeReport(path string, r report) error {
	buf, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	if err := os.WriteFile(path, buf, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}
