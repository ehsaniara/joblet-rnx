package version

import (
	"fmt"
	"runtime"
)

var (
	// These values are set at build time via -ldflags
	Version     = "dev"     // Version is the semantic version (e.g., v4.3.3)
	GitCommit   = "unknown" // GitCommit is the git commit hash
	GitTag      = "unknown" // GitTag is the git tag if available
	BuildDate   = "unknown" // BuildDate is when the binary was built
	Component   = "unknown" // Component identifies which component this is (rnx, joblet, api)
	ProtoCommit = "unknown" // ProtoCommit is the commit hash from joblet-proto repository
	ProtoTag    = "unknown" // ProtoTag is the tag from joblet-proto repository
)

// BuildInfo represents the complete build information
type BuildInfo struct {
	Version      string `json:"version"`
	GitCommit    string `json:"git_commit"`
	GitTag       string `json:"git_tag"`
	BuildDate    string `json:"build_date"`
	Component    string `json:"component"`
	GoVersion    string `json:"go_version"`
	Compiler     string `json:"compiler"`
	Platform     string `json:"platform"`
	Architecture string `json:"architecture"`
	ProtoCommit  string `json:"proto_commit"`
	ProtoTag     string `json:"proto_tag"`
}

// GetBuildInfo returns complete build information
func GetBuildInfo() BuildInfo {
	return BuildInfo{
		Version:      Version,
		GitCommit:    GitCommit,
		GitTag:       GitTag,
		BuildDate:    BuildDate,
		Component:    Component,
		GoVersion:    runtime.Version(),
		Compiler:     runtime.Compiler,
		Platform:     runtime.GOOS,
		Architecture: runtime.GOARCH,
		ProtoCommit:  ProtoCommit,
		ProtoTag:     ProtoTag,
	}
}

// GetVersion returns the version string
func GetVersion() string {
	if Version != "dev" {
		return Version
	}
	if GitTag != "unknown" && GitTag != "" {
		return GitTag
	}
	return fmt.Sprintf("dev-%s", GitCommit)
}

// GetShortVersion returns a concise version string for display
func GetShortVersion() string {
	version := GetVersion()
	if GitCommit != "unknown" && len(GitCommit) >= 8 {
		return fmt.Sprintf("%s (%s)", version, GitCommit[:8])
	}
	return version
}

// FormatVersion formats a version with optional commit hash
func FormatVersion(version, commit string) string {
	if commit != "unknown" && commit != "" && len(commit) >= 8 {
		return fmt.Sprintf("%s (%s)", version, commit[:8])
	}
	return version
}
