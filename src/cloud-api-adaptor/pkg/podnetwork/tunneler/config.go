// (C) Copyright Confidential Containers Contributors
// SPDX-License-Identifier: Apache-2.0

package tunneler

const DefaultNetworkNamespaceName = "peerpods"

type TunnelerConfigurator interface {
	Tunneler
	Initialize(*NetworkConfig) error
	Configure(*Config) error
}

type NetworkConfig struct {
	TunnelType    string
	HostInterface string
	Namespace     string
	VXLAN         VXLANConfig
	WireGuard     WireGuardConfig
}

type VXLANConfig struct {
	Port  int
	MinID int
}

type WireGuardConfig struct {
	Port int
	MTU  int
}
