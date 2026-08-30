// Package config loads the rnx client configuration (rnx-config.yml): the set
// of Joblet nodes to connect to and their embedded mTLS certificates.
//
// This is the client-only slice of the Joblet configuration surface. The server
// config (joblet-config.yml) lives in the joblet server repository; rnx and the
// server share no config file - only the proto contract (joblet-proto).
package config

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// ClientConfig is the rnx client configuration: a set of named nodes.
type ClientConfig struct {
	Version string           `yaml:"version"`
	Nodes   map[string]*Node `yaml:"nodes"`
}

// Node is a single Joblet server with embedded PEM certificates.
type Node struct {
	Address   string `yaml:"address"`
	NodeId    string `yaml:"nodeId,omitempty"`    // Node identifier (display only)
	IsDefault *bool  `yaml:"isDefault,omitempty"` // Used when --node is not specified
	Cert      string `yaml:"cert"`                // Embedded PEM client certificate
	Key       string `yaml:"key"`                 // Embedded PEM client private key
	CA        string `yaml:"ca"`                  // Embedded PEM CA certificate
}

// GetClientTLSConfig builds a mTLS client config from the node's embedded certs:
// presents the client cert, validates the server against the CA, TLS 1.3, and
// pins the server name to "joblet" to match the server certificate.
func (n *Node) GetClientTLSConfig() (*tls.Config, error) {
	if n.Cert == "" || n.Key == "" || n.CA == "" {
		return nil, fmt.Errorf("client certificates are not configured for node")
	}

	clientCert, err := tls.X509KeyPair([]byte(n.Cert), []byte(n.Key))
	if err != nil {
		return nil, fmt.Errorf("failed to load client certificate: %w", err)
	}

	caCertPool := x509.NewCertPool()
	if ok := caCertPool.AppendCertsFromPEM([]byte(n.CA)); !ok {
		return nil, fmt.Errorf("failed to parse CA certificate")
	}

	return &tls.Config{
		Certificates: []tls.Certificate{clientCert},
		RootCAs:      caCertPool,
		MinVersion:   tls.VersionTLS13,
		ServerName:   "joblet", // Must match server certificate
	}, nil
}

// LoadClientConfig loads rnx-config.yml from configPath, or searches the standard
// locations when configPath is empty. Requires at least one node and at most one
// node marked isDefault: true.
func LoadClientConfig(configPath string) (*ClientConfig, error) {
	if configPath == "" {
		configPath = findClientConfig()
		if configPath == "" {
			return nil, fmt.Errorf("client configuration file not found. Please create rnx-config.yml or specify path with --config")
		}
	}

	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("client configuration file not found: %s", configPath)
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read client config file %s: %w", configPath, err)
	}

	var config ClientConfig
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse client config: %w", err)
	}

	if len(config.Nodes) == 0 {
		return nil, fmt.Errorf("no nodes configured in %s", configPath)
	}

	var defaults []string
	for name, node := range config.Nodes {
		if node.IsDefault != nil && *node.IsDefault {
			defaults = append(defaults, name)
		}
	}
	if len(defaults) > 1 {
		sort.Strings(defaults)
		return nil, fmt.Errorf("multiple nodes marked with isDefault: true in %s: %s (only one node can be the default)",
			configPath, strings.Join(defaults, ", "))
	}

	return &config, nil
}

// DefaultNodeName returns the node used when no --node is given: the node marked
// isDefault: true, else a node literally named "default", else the sole node.
// Empty string if none can be determined.
func (c *ClientConfig) DefaultNodeName() string {
	for name, node := range c.Nodes {
		if node.IsDefault != nil && *node.IsDefault {
			return name
		}
	}
	if _, exists := c.Nodes["default"]; exists {
		return "default"
	}
	if len(c.Nodes) == 1 {
		for name := range c.Nodes {
			return name
		}
	}
	return ""
}

// GetNode returns the named node, resolving the default when nodeName is empty.
func (c *ClientConfig) GetNode(nodeName string) (*Node, error) {
	if nodeName == "" {
		nodeName = c.DefaultNodeName()
		if nodeName == "" {
			return nil, fmt.Errorf("no default node configured: mark one node with isDefault: true or use --node to select one of: %s",
				strings.Join(c.ListNodes(), ", "))
		}
	}

	node, exists := c.Nodes[nodeName]
	if !exists {
		return nil, fmt.Errorf("node '%s' not found in configuration", nodeName)
	}

	return node, nil
}

// ListNodes returns all configured node names, sorted.
func (c *ClientConfig) ListNodes() []string {
	nodes := make([]string, 0, len(c.Nodes))
	for name := range c.Nodes {
		nodes = append(nodes, name)
	}
	sort.Strings(nodes)
	return nodes
}

// findClientConfig searches RNX_CONFIG then the standard locations, returning the
// first rnx-config.yml found, or empty string.
func findClientConfig() string {
	if envPath := os.Getenv("RNX_CONFIG"); envPath != "" {
		if _, err := os.Stat(envPath); err == nil {
			return envPath
		}
	}

	locations := []string{
		"./rnx-config.yml",
		"./config/rnx-config.yml",
		filepath.Join(os.Getenv("HOME"), ".rnx", "rnx-config.yml"),
		"/etc/joblet/rnx-config.yml",
		"/opt/joblet/config/rnx-config.yml",
	}

	for _, path := range locations {
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}

	return ""
}
