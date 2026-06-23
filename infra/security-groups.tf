# ---- Node Security Group ----
resource "aws_security_group" "jerney_nodegroup" {
  name_prefix = "${var.cluster_name}-node-"
  description = "Explicit security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Node-to-node: pods on different nodes must reach each other on any port.
resource "aws_security_group_rule" "node_ingress_self" {
  description       = "Allow node-to-node traffic (pod networking)"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.jerney_nodegroup.id
  self              = true
}

# Control plane -> node: kubelet API and ephemeral ports used by the API
# server for exec/logs, metrics scraping and admission webhooks.
resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow control plane to reach node kubelet/ephemeral ports"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jerney_nodegroup.id
  source_security_group_id = aws_eks_cluster.jerney_ekscluster.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow all outbound (intentional baseline, tighten later)"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.jerney_nodegroup.id
  cidr_blocks       = ["0.0.0.0/0"]
}
