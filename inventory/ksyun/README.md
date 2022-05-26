# 金山云 K8s 部署

操作见：[docs/getting-started.md](/docs/getting-started.md)

SSH 私钥 `ksyun.pem` 可以找 @Thearas 要。

E.g.

```sh
ansible-playbook -i inventory/ksyun/hosts.yaml  --private-key ksyun.pem -uroot --become --become-user=root cluster.yml
```

Only upgrade network components:

```sh
ansible-playbook -i inventory/ksyun/hosts.yaml  --private-key ksyun.pem -uroot --become --become-user=root cluster.yml --tags=network
```
