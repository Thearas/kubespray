local namespace(ns) =
  std.parseYaml(|||
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: jenkins-admin
      namespace: %(ns)s
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: User
      name: jenkins
      namespace: %(ns)s
||| % {
  ns: ns
  }
);

{
  apiVersion: "v1",
  kind: "List",
  items: [ namespace(ns) for ns in ["jenkins-cd", "jenkins-ci-default", "jenkins-dm", "jenkins-org-tikv", "jenkins-pd", "jenkins-qa", "jenkins-ti-pipeline", "jenkins-tibigdata", "jenkins-ticdc", "jenkins-tidb", "jenkins-tidb-binlog", "jenkins-tidb-mergeci", "jenkins-tidb-operator", "jenkins-tidb-test", "jenkins-tiflash", "jenkins-tikv", "jenkins-tispark"]]
}