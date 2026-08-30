package common

import (
	"fmt"

	"github.com/ehsaniara/joblet-rnx/v6/pkg/client"
	"github.com/ehsaniara/joblet-rnx/v6/pkg/config"
)

var (
	NodeConfig *config.ClientConfig
	ConfigPath string
	NodeName   string
	JSONOutput bool
)

// NewJobClient creates a client based on configuration
func NewJobClient() (*client.JobClient, error) {
	// NodeConfig should be loaded by PersistentPreRun
	if NodeConfig == nil {
		return nil, fmt.Errorf("no configuration loaded - this should not happen")
	}

	node, err := NodeConfig.GetNode(NodeName)
	if err != nil {
		return nil, fmt.Errorf("failed to get node configuration for '%s': %w", NodeName, err)
	}

	return client.NewJobClient(node)
}
