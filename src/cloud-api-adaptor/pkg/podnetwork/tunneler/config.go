// (C) Copyright Confidential Containers Contributors
// SPDX-License-Identifier: Apache-2.0

package tunneler

type TunnelerConfigurator interface {
	Tunneler
	Initialize(*NetworkConfig) error
	Configure(*Config) error
}

type NetworkConfig struct {
	TunnelType    string
	HostInterface string
	VXLAN         VXLANConfig
}

type VXLANConfig struct {
	Port  int
	MinID int
}
