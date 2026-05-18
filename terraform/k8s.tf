locals {
  api_rbac_docs = [
    for doc in split("---", trim(file("${path.module}/../k8s/rbac/api-role.yaml"))) :
    yamldecode(doc)
    if trim(doc) != ""
  ]

  nginx_rbac_docs = [
    for doc in split("---", trim(file("${path.module}/../k8s/rbac/nginx-role.yaml"))) :
    yamldecode(doc)
    if trim(doc) != ""
  ]

  minio_rbac_docs = [
    for doc in split("---", trim(file("${path.module}/../k8s/rbac/minio-role.yaml"))) :
    yamldecode(doc)
    if trim(doc) != ""
  ]

  network_policy_docs = [
    for doc in split("---", trim(file("${path.module}/../k8s/network-policy.yml"))) :
    yamldecode(doc)
    if trim(doc) != ""
  ]
}

resource "kubernetes_manifest" "api_serviceaccount" {
  manifest = yamldecode(file("${path.module}/../k8s/api/serviceaccount.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "api_configmap" {
  manifest = yamldecode(file("${path.module}/../k8s/api/configmap.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "api_service" {
  manifest = yamldecode(file("${path.module}/../k8s/api/service.yml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "api_pdb" {
  manifest = yamldecode(file("${path.module}/../k8s/api/pdb.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "api_rbac" {
  for_each = { for idx, doc in local.api_rbac_docs : idx => doc }
  manifest = each.value
  depends_on = [module.cluster, kubernetes_manifest.api_serviceaccount]
}

resource "kubernetes_manifest" "api_deployment" {
  manifest = yamldecode(file("${path.module}/../k8s/api/deployment.yaml"))
  depends_on = [
    module.cluster,
    kubernetes_manifest.api_serviceaccount,
    kubernetes_manifest.api_configmap,
    kubernetes_secret.api_secrets
  ]
}

resource "kubernetes_manifest" "nginx_serviceaccount" {
  manifest = yamldecode(file("${path.module}/../k8s/nginx/serviceaccount.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "nginx_configmap" {
  manifest = yamldecode(file("${path.module}/../k8s/nginx/configmap.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "nginx_service" {
  manifest = yamldecode(file("${path.module}/../k8s/nginx/service.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "nginx_rbac" {
  for_each = { for idx, doc in local.nginx_rbac_docs : idx => doc }
  manifest = each.value
  depends_on = [module.cluster, kubernetes_manifest.nginx_serviceaccount]
}

resource "kubernetes_manifest" "nginx_deployment" {
  manifest = yamldecode(file("${path.module}/../k8s/nginx/deployment.yaml"))
  depends_on = [
    module.cluster,
    kubernetes_manifest.nginx_serviceaccount,
    kubernetes_manifest.nginx_configmap,
    kubernetes_secret.nginx_tls,
    kubernetes_secret.nginx_htpasswd
  ]
}

resource "kubernetes_manifest" "minio_serviceaccount" {
  manifest = yamldecode(file("${path.module}/../k8s/minio/serviceaccount.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "minio_pvc" {
  manifest = yamldecode(file("${path.module}/../k8s/minio/pvc.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "minio_service" {
  manifest = yamldecode(file("${path.module}/../k8s/minio/service.yaml"))
  depends_on = [module.cluster]
}

resource "kubernetes_manifest" "minio_rbac" {
  for_each = { for idx, doc in local.minio_rbac_docs : idx => doc }
  manifest = each.value
  depends_on = [module.cluster, kubernetes_manifest.minio_serviceaccount]
}

resource "kubernetes_manifest" "minio_deployment" {
  manifest = yamldecode(file("${path.module}/../k8s/minio/deployment.yaml"))
  depends_on = [
    module.cluster,
    kubernetes_manifest.minio_serviceaccount,
    kubernetes_manifest.minio_pvc,
    kubernetes_secret.minio_secrets
  ]
}

resource "kubernetes_manifest" "network_policy" {
  for_each = { for idx, doc in local.network_policy_docs : idx => doc }
  manifest = each.value
  depends_on = [module.cluster]
}
