// Command k3s_extras is the guest-side test binary of
// //tests/k3s:k3s_extras_test. It checks that every extra_* attribute of
// firecracker_k3s_test reached the guest, and that the launcher's flag
// contract is honored, then writes a pass_conditions report.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"
)

type pc struct {
	ID     string `json:"id"`
	Label  string `json:"label"`
	Passed bool   `json:"passed"`
	Error  string `json:"error,omitempty"`
}

type report struct {
	Scenario       string `json:"scenario"`
	PassConditions []pc   `json:"pass_conditions"`
}

func kubectl(kubeconfig string, args ...string) (string, error) {
	cmd := exec.Command("/usr/local/bin/k3s", append([]string{"kubectl", "--kubeconfig=" + kubeconfig}, args...)...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// poll retries f every 2s until it succeeds or the timeout passes.
func poll(timeout time.Duration, f func() error) error {
	deadline := time.Now().Add(timeout)
	for {
		err := f()
		if err == nil || time.Now().After(deadline) {
			return err
		}
		time.Sleep(2 * time.Second)
	}
}

func check(rep *report, id string, err error) {
	p := pc{ID: id, Label: id, Passed: err == nil}
	if err != nil {
		p.Error = err.Error()
	}
	rep.PassConditions = append(rep.PassConditions, p)
}

func main() {
	var scenario, reportPath, kubeconfig, namespace string
	flag.StringVar(&scenario, "scenario", "", "scenario YAML path")
	flag.StringVar(&reportPath, "report-json", "/tmp/report.json", "report output")
	flag.StringVar(&kubeconfig, "kubeconfig", "", "kubeconfig")
	flag.StringVar(&namespace, "namespace", "", "namespace")
	flag.Parse()

	rep := report{Scenario: "k3s_extras"}

	// The launcher's flag contract.
	check(&rep, "flags.scenario", func() error {
		if scenario != "/etc/manifests/k3s_extras.yaml" {
			return fmt.Errorf("--scenario=%q", scenario)
		}
		if _, err := os.Stat(scenario); err != nil {
			return err
		}
		return nil
	}())
	check(&rep, "flags.kubeconfig+namespace", func() error {
		if kubeconfig != "/etc/rancher/k3s/k3s.yaml" || namespace != "default" {
			return fmt.Errorf("--kubeconfig=%q --namespace=%q", kubeconfig, namespace)
		}
		return nil
	}())

	// extra_manifests: applied by k3s_init after the node is Ready.
	check(&rep, "extra_manifests.applied", poll(60*time.Second, func() error {
		out, err := kubectl(kubeconfig, "get", "configmap", "fc-fixture", "-n", "default", "-o", "jsonpath={.data.marker}")
		if err != nil {
			return fmt.Errorf("%v: %s", err, out)
		}
		if out != "from-extra-manifest" {
			return fmt.Errorf("configmap data.marker=%q", out)
		}
		return nil
	}))

	// extra_files: 0644 at the requested path.
	check(&rep, "extra_files.installed", func() error {
		b, err := os.ReadFile("/etc/fcextra/data.txt")
		if err != nil {
			return err
		}
		if strings.TrimSpace(string(b)) != "extra file payload" {
			return fmt.Errorf("content %q", b)
		}
		st, err := os.Stat("/etc/fcextra/data.txt")
		if err != nil {
			return err
		}
		if st.Mode().Perm() != 0o644 {
			return fmt.Errorf("mode %v", st.Mode().Perm())
		}
		// The image is packed by an unprivileged build user; the file must
		// still be root-owned in the guest, not owned by that user's uid.
		if sys, ok := st.Sys().(*syscall.Stat_t); !ok {
			return fmt.Errorf("stat: no ownership info (%T)", st.Sys())
		} else if sys.Uid != 0 || sys.Gid != 0 {
			return fmt.Errorf("owner %d:%d, want 0:0", sys.Uid, sys.Gid)
		}
		return nil
	}())

	// extra_execs: 0755 and runnable.
	check(&rep, "extra_execs.runnable", func() error {
		out, err := exec.Command("/opt/extra/busybox", "echo", "exec-ok").CombinedOutput()
		if err != nil || strings.TrimSpace(string(out)) != "exec-ok" {
			return fmt.Errorf("run: %v: %s", err, out)
		}
		return nil
	}())

	// extra_images: auto-imported into k3s' containerd from
	// /var/lib/rancher/k3s/agent/images (no registry access in the VM).
	check(&rep, "extra_images.imported", poll(90*time.Second, func() error {
		out, err := exec.Command("/usr/local/bin/k3s", "ctr", "-n", "k8s.io", "images", "ls", "-q").CombinedOutput()
		if err != nil {
			return fmt.Errorf("ctr images ls: %v: %s", err, out)
		}
		if !strings.Contains(string(out), "fctest/extra:latest") {
			return fmt.Errorf("fctest/extra:latest not imported; images:\n%s", out)
		}
		return nil
	}))

	buf, err := json.MarshalIndent(rep, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, "marshal report:", err)
		os.Exit(1)
	}
	if err := os.WriteFile(reportPath, buf, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "write report:", err)
		os.Exit(1)
	}
	for _, p := range rep.PassConditions {
		if !p.Passed {
			os.Exit(1)
		}
	}
}
