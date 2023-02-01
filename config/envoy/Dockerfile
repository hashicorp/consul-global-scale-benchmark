# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

FROM envoyproxy/envoy:v1.16.0

RUN apt-get update && \
    apt-get install -y netcat && \
    apt-get install -y coreutils

LABEL "com.datadoghq.ad.logs"='[{"source":"envoy","service":"envoy","log_processing_rules":[{"type":"include_at_match","name":"include_envoy_log_entries","pattern":"cluster_manager_impl"}]}]'
