# Messager quickstart

Микросервисный мессенджер, развёрнутый в Kubernetes.

Используется:

* Kubernetes;
* Kustomize;
* PostgreSQL;
* MinIO;
* S3 CSI volume;
* nodeAffinity;
* Argo CD.

---

## 1. Требования

Перед запуском должны быть установлены:

```text
docker
kubectl
minikube
git
```

---

## 2. Запуск кластера

```bash
minikube start --driver=docker --nodes=3 --cpus=2 --memory=4096 --addons=ingress
```

```bash
kubectl get nodes
```

---

## 3. Разметка узлов

```bash
kubectl label node minikube workload=system --overwrite
kubectl label node minikube-m02 workload=app --overwrite
kubectl label node minikube-m03 workload=app disk=fast --overwrite
```

```bash
kubectl get nodes -L workload,disk
```

Размещение:

```text
postgres, minio             -> workload=system
frontend, bff, user-service -> workload=app
message-service             -> workload=app, disk=fast
```

---

## 4. Установка S3 CSI driver

```bash
git clone https://github.com/ctrox/csi-s3.git /tmp/csi-s3

kubectl apply -f /tmp/csi-s3/deploy/kubernetes/provisioner.yaml
kubectl apply -f /tmp/csi-s3/deploy/kubernetes/attacher.yaml
kubectl apply -f /tmp/csi-s3/deploy/kubernetes/csi-s3.yaml
```

```bash
kubectl get pods -n kube-system | grep -E 'csi|s3'
```

Если CSI Pod’ы находятся в `ErrImagePull` или `ImagePullBackOff`, обновить sidecar images:

```bash
kubectl set image statefulset/csi-attacher-s3 -n kube-system \
  csi-attacher=registry.k8s.io/sig-storage/csi-attacher:v4.10.0

kubectl set image statefulset/csi-provisioner-s3 -n kube-system \
  csi-provisioner=registry.k8s.io/sig-storage/csi-provisioner:v5.2.0

kubectl set image daemonset/csi-s3 -n kube-system \
  driver-registrar=registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0

kubectl rollout restart daemonset/csi-s3 -n kube-system
```

---

## 5. Запуск dev

```bash
kubectl apply -k k8s/overlays/dev
```

```bash
kubectl get pods -n messager-dev
kubectl get pvc -n messager-dev
kubectl get svc -n messager-dev
```

Для просмотра размещения Pod’ов по узлам:

```bash
kubectl get pods -n messager-dev -o wide
```

---

## 6. Доступ к приложению

Через port-forward:

```bash
kubectl port-forward -n messager-dev svc/frontend 3000:80
```

```text
http://localhost:3000
```

Через Ingress:

```bash
echo "$(minikube ip) messager.local" | sudo tee -a /etc/hosts
```

```text
http://messager.local
```

---

## 7. Запуск prod

```bash
kubectl apply -k k8s/overlays/prod
```

```bash
kubectl get pods -n messager-prod
kubectl get svc -n messager-prod
```

---

## 8. Argo CD

Перед запуском заменить `repoURL` в файлах:

```text
argocd/application-dev.yaml
argocd/application-prod.yaml
```

Установка Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Применение приложений:

```bash
kubectl apply -f argocd/application-dev.yaml
kubectl apply -f argocd/application-prod.yaml
```

Проверка:

```bash
kubectl get application -n argocd
```

---

## 9. Диагностика

```bash
kubectl get events -n messager-dev --sort-by=.lastTimestamp
kubectl describe pod -n messager-dev <pod-name>
kubectl logs -n messager-dev <pod-name>
kubectl get pods -n kube-system | grep -E 'csi|s3'
```

---

## 10. Очистка

```bash
kubectl delete -k k8s/overlays/dev
kubectl delete -k k8s/overlays/prod
minikube delete
```
