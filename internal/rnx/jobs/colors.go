package jobs

// getStatusColor returns the ANSI color code for a given status
func getStatusColor(status string) (string, string) {
	var statusColor string
	switch status {
	case "RUNNING":
		statusColor = "\033[33m" // Yellow
	case "COMPLETED":
		statusColor = "\033[32m" // Green
	case "FAILED":
		statusColor = "\033[31m" // Red
	case "SCHEDULED":
		statusColor = "\033[36m" // Cyan
	case "STOPPED":
		statusColor = "\033[35m" // Magenta
	case "INITIALIZING":
		statusColor = "\033[34m" // Blue
	case "PENDING":
		statusColor = "\033[36m" // Cyan
	case "CANCELED":
		statusColor = "\033[35m" // Magenta
	default:
		statusColor = ""
	}
	resetColor := "\033[0m"
	return statusColor, resetColor
}
