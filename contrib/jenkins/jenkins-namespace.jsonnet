local namespace(ns) =
  std.parseYaml(|||
    apiVersion: v1
    kind: Namespace
    metadata:
      labels:
        app.kubernetes.io/managed-by: jenkins
        kubernetes.io/metadata.name: %(ns)s
      name: %(ns)s
||| % {
  ns: ns
  }
);

{
  apiVersion: "v1",
  kind: "List",
  items: [ namespace(ns) for ns in ["jenkins-cd", "jenkins-ci-default", "jenkins-dm", "jenkins-org-tikv", "jenkins-pd", "jenkins-qa", "jenkins-ti-pipeline", "jenkins-tibigdata", "jenkins-ticdc", "jenkins-tidb", "jenkins-tidb-binlog", "jenkins-tidb-mergeci", "jenkins-tidb-operator", "jenkins-tidb-test", "jenkins-tiflash", "jenkins-tikv", "jenkins-tispark"]]
}