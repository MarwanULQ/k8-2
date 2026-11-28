locals {
  observability_nodeports = {
    argocd       = 30443
    grafana      = 30300
    prometheus   = 30090
    alertmanager = 30903
    loki         = 30310
    alloy        = 31235
  }
}

resource "aws_security_group_rule" "observability_admin" {
  for_each          = var.enable_nodeport_ingress ? local.observability_nodeports : {}
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "${each.key} NodePort from administrator"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
}

output "observability_nodeports" {
  value = local.observability_nodeports
}
