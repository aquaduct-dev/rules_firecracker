// Unit tests for k3s_smoke's parsing of the `k3s kubectl get nodes` JSONPath
// output, which otherwise only runs inside the k3s microVM.
package main

import "testing"

func TestHasReady(t *testing.T) {
	for _, tc := range []struct {
		name string
		out  string
		want bool
	}{
		{"one ready node", "node1\tTrue\n", true},
		{"no trailing newline", "node1\tTrue", true},
		{"not ready", "node1\tFalse\n", false},
		{"unknown", "node1\tUnknown\n", false},
		{"second node ready", "node1\tFalse\nnode2\tTrue\n", true},
		{"empty output", "", false},
		{"no status yet", "node1\t\n", false},
		{"name only, no tab", "True\n", false},
		{"status with suffix", "node1\tTrueish\n", false},
		{"blank lines", "\n\nnode1\tTrue\n\n", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := hasReady(tc.out); got != tc.want {
				t.Errorf("hasReady(%q) = %v, want %v", tc.out, got, tc.want)
			}
		})
	}
}
