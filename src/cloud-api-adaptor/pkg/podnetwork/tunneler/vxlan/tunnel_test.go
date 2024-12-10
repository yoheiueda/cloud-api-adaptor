// (C) Copyright IBM Corp. 2022.
// SPDX-License-Identifier: Apache-2.0

package vxlan

import (
	"testing"

	"github.com/confidential-containers/cloud-api-adaptor/src/cloud-api-adaptor/pkg/podnetwork/tunneler"
	"github.com/confidential-containers/cloud-api-adaptor/src/cloud-api-adaptor/pkg/podnetwork/tuntest"
)

func TestVXLAN(t *testing.T) {

	networkConfig := &tunneler.NetworkConfig{
		TunnelType: "vxlan",
		VXLAN: tunneler.VXLANConfig{
			Port:  4789,
			MinID: 555000,
		},
	}

	tuntest.RunTunnelTest(t, "vxlan", NewWorkerNodeTunneler, NewPodNodeTunneler, networkConfig)

}
