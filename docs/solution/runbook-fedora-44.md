# Пошаговое решение лабораторной работы для Fedora 44

## 0. Что было добавлено в репозиторий

Добавлены каталоги:

```text
k8s/base/                  # базовые Kubernetes-манифесты
k8s/overlays/dev/          # dev overlay: namespace messager-dev, 1 replica, latest images
k8s/overlays/prod/         # prod overlay: namespace messager-prod, 2 replicas для app-сервисов, повышенные resources
argocd/                    # Argo CD Application для dev/prod
docs/solution/             # runbook и описание решения
```

Решение использует готовые образы из README:

```text
mablinov2704/frontend:latest
mablinov2704/bff:latest
mablinov2704/user-service:latest
mablinov2704/message-service:latest
postgres:16-alpine
ghcr.io/kukymbr/goose-docker:latest
minio/minio:latest
```

Важное замечание: в `k8s/base/secret.yaml` стоят учебные значения `change-me-*`. Перед публикацией репозитория и особенно перед `prod` замените их на свои значения.

## 1. Установка утилит на Fedora 44

### 1.1. Базовые утилиты

```bash
sudo dnf upgrade --refresh -y
sudo dnf install -y unzip git curl wget jq tar bash-completion dnf-plugins-core
```

Ожидаемый результат: команды завершаются без ошибок, в конце обычно видно `Complete!` или `Nothing to do.`.

### 1.2. Docker Engine

```bash
sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine || true
sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

Проверка:

```bash
docker version
docker run --rm hello-world
```

Ожидаемый результат:

```text
Client: Docker Engine ...
Server: Docker Engine ...
Hello from Docker!
```

### 1.3. kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

Ожидаемый результат:

```text
kubectl: OK
Client Version: v...
Kustomize Version: v...
```

### 1.4. minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
sudo rpm -Uvh minikube-latest.x86_64.rpm
rm -f minikube-latest.x86_64.rpm
minikube version
```

Ожидаемый результат:

```text
minikube version: v...
```

### 1.5. kustomize

Отдельный `kustomize` устанавливать необязательно: он встроен в `kubectl`, поэтому команды ниже используют `kubectl kustomize`. Если преподаватель требует именно команду `kustomize build`, можно установить standalone-версию:

```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/kustomize
kustomize version
```

Ожидаемый результат:

```text
v...
```

## 2. Распаковка архива и переход в репозиторий

```bash
mkdir -p ~/labs
cd ~/labs
unzip /path/to/lab-k8s-messager-main.zip
cd lab-k8s-messager-main
```

Ожидаемый результат:

```text
Archive:  lab-k8s-messager-main.zip
  inflating: lab-k8s-messager-main/README.md
  inflating: lab-k8s-messager-main/docs/...
```

Проверка:

```bash
ls
```

Ожидаемый результат:

```text
README.md  bff  frontend  message-service  user-service  docs  docker-compose.yml ...
```

## 3. Создание локального Kubernetes-кластера

Требование `nodeAffinity` предполагает разные классы узлов: `workload=system`, `workload=app`, плюс `disk=fast` для части app-узлов. Поэтому для локальной защиты удобнее запустить 3-node minikube.

```bash
minikube start --driver=docker --nodes=3 --cpus=2 --memory=4096 --addons=ingress
```

Ожидаемый результат:

```text
Done! kubectl is now configured to use "minikube" cluster and "default" namespace
```

Проверка:

```bash
kubectl get nodes
```

Ожидаемый результат:

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   ...   v...
minikube-m02   Ready    <none>          ...   v...
minikube-m03   Ready    <none>          ...   v...
```

## 4. Разметка узлов для nodeAffinity

```bash
kubectl label node minikube workload=system --overwrite
kubectl label node minikube-m02 workload=app --overwrite
kubectl label node minikube-m03 workload=app disk=fast --overwrite
kubectl get nodes --show-labels | grep -E 'workload=|disk=fast'
```

Ожидаемый результат: у `minikube` есть `workload=system`, у `minikube-m02` есть `workload=app`, у `minikube-m03` есть `workload=app,disk=fast`.

Если имена узлов отличаются, сначала посмотрите их:

```bash
kubectl get nodes
```

и подставьте свои имена вместо `minikube`, `minikube-m02`, `minikube-m03`.

## 5. Установка S3 CSI driver

Лабораторная требует подключение файлов через CSI, а не обычный PVC. В манифестах используется CSI driver `ch.ctrox.csi.s3-driver`.

```bash
git clone https://github.com/ctrox/csi-s3.git /tmp/csi-s3
kubectl apply -f /tmp/csi-s3/deploy/kubernetes/provisioner.yaml
kubectl apply -f /tmp/csi-s3/deploy/kubernetes/attacher.yaml
kubectl apply -f /tmp/csi-s3/deploy/kubernetes/csi-s3.yaml
kubectl get pods -n kube-system | grep -E 'csi|s3'
```

Ожидаемый результат:

```text
csi-attacher-s3-...      Running
csi-provisioner-s3-...   Running
csi-s3-...               Running
```

Если Pod не стартует, смотрите логи:

```bash
kubectl logs -n kube-system -l app=csi-s3 -c csi-s3 --tail=100
kubectl logs -n kube-system -l app=csi-provisioner-s3 -c csi-s3 --tail=100
```

## 6. Проверка kustomize overlays

```bash
kubectl kustomize k8s/overlays/dev > /tmp/messager-dev.yaml
kubectl kustomize k8s/overlays/prod > /tmp/messager-prod.yaml
```

Ожидаемый результат: команды ничего не печатают в stderr и создают файлы.

Проверка:

```bash
head -20 /tmp/messager-dev.yaml
grep -n "kind: Deployment" /tmp/messager-dev.yaml | head
grep -n "messager-prod" /tmp/messager-prod.yaml | head
```

Ожидаемый результат: в YAML видны `Namespace`, `Deployment`, `Service`, `PersistentVolume`, `PersistentVolumeClaim`, `Job`, `Ingress`.

## 7. Деплой dev overlay

Перед повторным деплоем удобно удалить старые Job, потому что Job spec в Kubernetes неизменяемый:

```bash
kubectl delete job migrate-users migrate-messages minio-create-bucket -n messager-dev --ignore-not-found
kubectl apply -k k8s/overlays/dev
```

Ожидаемый результат:

```text
namespace/messager-dev created
configmap/messager-config created
secret/messager-db-secret created
deployment.apps/postgres created
deployment.apps/minio created
persistentvolume/s3-pv-messager-dev-uploads created
persistentvolumeclaim/message-uploads-pvc created
job.batch/migrate-users created
job.batch/migrate-messages created
deployment.apps/user-service created
deployment.apps/message-service created
deployment.apps/bff created
deployment.apps/frontend created
ingress.networking.k8s.io/messager-ingress created
```

## 8. Ожидание запуска

```bash
kubectl get pods -n messager-dev -w
```

Ожидаемый результат:

```text
postgres-...              1/1   Running
minio-...                 1/1   Running
minio-create-bucket-...   0/1   Completed
migrate-users-...         0/1   Completed
migrate-messages-...      0/1   Completed
user-service-...          1/1   Running
message-service-...       1/1   Running
bff-...                   1/1   Running
frontend-...              1/1   Running
```

Если что-то зависло:

```bash
kubectl describe pod <pod-name> -n messager-dev
kubectl logs <pod-name> -n messager-dev --all-containers --tail=100
```

## 9. Проверка nodeAffinity

```bash
kubectl get pods -n messager-dev -o wide
```

Ожидаемый результат:

```text
postgres-...         Running   ...   NODE=minikube
minio-...            Running   ...   NODE=minikube
frontend-...         Running   ...   NODE=minikube-m02 или minikube-m03
bff-...              Running   ...   NODE=minikube-m02 или minikube-m03
user-service-...     Running   ...   NODE=minikube-m02 или minikube-m03
message-service-...  Running   ...   NODE=minikube-m03 желательно, потому что disk=fast
```

Проверка конкретного Pod:

```bash
POD=$(kubectl get pod -n messager-dev -l app=message-service -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n messager-dev | sed -n '/Node-Selectors/,/Events/p'
```

Ожидаемый результат: в описании видна node affinity: hard-условие `workload In app` и preferred-условие `disk In fast`.

## 10. Проверка PVC и S3 CSI mount

```bash
kubectl get pv,pvc -n messager-dev
```

Ожидаемый результат:

```text
persistentvolume/s3-pv-messager-dev-uploads   ...   Bound   messager-dev/message-uploads-pvc
persistentvolumeclaim/message-uploads-pvc     Bound
```

Проверка внутри `message-service`:

```bash
POD=$(kubectl get pod -n messager-dev -l app=message-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n messager-dev "$POD" -- sh -c 'mount | grep /app/uploads || true; ls -la /app/uploads'
```

Ожидаемый результат: каталог `/app/uploads` существует. В `mount` обычно виден FUSE/rclone/s3fs mount, если CSI driver смонтировал S3.

## 11. Доступ к приложению через Ingress

Получите IP minikube:

```bash
minikube ip
```

Допустим, команда вернула `192.168.49.2`. Добавьте host:

```bash
echo "$(minikube ip) dev.messager.local" | sudo tee -a /etc/hosts
```

Проверка:

```bash
curl -I http://dev.messager.local/
```

Ожидаемый результат:

```text
HTTP/1.1 200 OK
```

Откройте в браузере:

```text
http://dev.messager.local/
```

Ожидаемый результат: открывается интерфейс Messager.

## 12. Проверка API без браузера

Создайте двух пользователей через BFF:

```bash
curl -s -X POST http://dev.messager.local/api/v1/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice"}' | jq

curl -s -X POST http://dev.messager.local/api/v1/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Bob"}' | jq
```

Ожидаемый результат: JSON с `id`, `name`, `created_at`.

Найдите пользователей:

```bash
curl -s 'http://dev.messager.local/api/v1/users?q=A' | jq
curl -s 'http://dev.messager.local/api/v1/users?q=B' | jq
```

Ожидаемый результат: массив пользователей.

Отправка сообщения:

```bash
ALICE_ID=$(curl -s 'http://dev.messager.local/api/v1/users?q=Alice' | jq -r '.[0].id')
BOB_ID=$(curl -s 'http://dev.messager.local/api/v1/users?q=Bob' | jq -r '.[0].id')

curl -s -X POST http://dev.messager.local/api/v1/messages \
  -H 'Content-Type: application/json' \
  -d "{\"sender_id\":\"$ALICE_ID\",\"receiver_id\":\"$BOB_ID\",\"text\":\"hello from k8s\"}" | jq
```

Ожидаемый результат: JSON сообщения с `id`, `sender_id`, `receiver_id`, `text`.

## 13. Проверка загрузки файла через S3 CSI

Создайте тестовый файл:

```bash
echo 'hello s3 csi' > /tmp/hello.txt
```

Загрузите файл через BFF:

```bash
curl -s -X POST http://dev.messager.local/api/v1/files \
  -F 'file=@/tmp/hello.txt' | jq
```

Ожидаемый результат:

```json
{
  "id": "...",
  "name": "hello.txt",
  "url": "/api/v1/files/..."
}
```

Проверьте, что файл появился в bucket MinIO:

```bash
kubectl run mc-check -n messager-dev --rm -it --restart=Never --image=minio/mc:latest -- \
  sh -c 'mc alias set local http://minio:9000 messager-minio change-me-minio-secret >/dev/null && mc ls -r local/messager-uploads'
```

Ожидаемый результат: в списке есть объект с UUID-подобным именем и расширением `.txt`.

Проверьте, что после перезапуска Pod файл остался:

```bash
kubectl delete pod -n messager-dev -l app=message-service
kubectl rollout status deployment/message-service -n messager-dev
kubectl run mc-check-2 -n messager-dev --rm -it --restart=Never --image=minio/mc:latest -- \
  sh -c 'mc alias set local http://minio:9000 messager-minio change-me-minio-secret >/dev/null && mc ls -r local/messager-uploads'
```

Ожидаемый результат: объект всё ещё виден в bucket.

## 14. Подготовка GitHub-репозитория

```bash
git init
git add README.md docs k8s argocd .gitignore
git commit -m "Add Kubernetes lab solution"
git branch -M main
git remote add origin https://github.com/<your-user>/<your-repo>.git
git push -u origin main
```

Ожидаемый результат:

```text
[main ...] Add Kubernetes lab solution
Enumerating objects: ...
To https://github.com/<your-user>/<your-repo>.git
 * [new branch] main -> main
```

Перед `git push` замените `YOUR_GITHUB_USER/YOUR_REPOSITORY` в `argocd/application-dev.yaml` и `argocd/application-prod.yaml`.

## 15. Установка Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd -w
```

Ожидаемый результат: все Pod в `argocd` переходят в `Running`.

Примените Application:

```bash
kubectl apply -f argocd/application-dev.yaml
kubectl get application -n argocd
```

Ожидаемый результат:

```text
NAME           SYNC STATUS   HEALTH STATUS
messager-dev   Synced        Healthy
```

Если статус не `Synced/Healthy`:

```bash
kubectl describe application messager-dev -n argocd
kubectl get events -n argocd --sort-by='.lastTimestamp' | tail -30
```

## 16. Проверка selfHeal и prune

Проверка selfHeal:

```bash
kubectl scale deployment frontend -n messager-dev --replicas=3
kubectl get deployment frontend -n messager-dev
```

Ожидаемый результат: сначала replicas станет 3, затем Argo CD вернёт значение из Git — 1 для dev overlay.

Проверка prune: добавьте временный ресурс в Git, дождитесь синка, удалите его из Git и проверьте, что Argo CD удалил его из кластера.

## 17. Что показать на защите

```bash
kubectl kustomize k8s/overlays/dev >/tmp/dev.yaml
kubectl kustomize k8s/overlays/prod >/tmp/prod.yaml
kubectl get pods -n messager-dev -o wide
kubectl get pv,pvc -n messager-dev
kubectl get ingress -n messager-dev
kubectl get application -n argocd
kubectl describe application messager-dev -n argocd | sed -n '/Sync Policy/,/Events/p'
```

Ожидаемые ключевые признаки:

- `dev` и `prod` overlays собираются;
- `postgres` и `minio` стоят на `workload=system`;
- frontend/bff/user-service/message-service стоят на `workload=app`;
- `message-service` предпочитает node с `disk=fast`;
- `message-uploads-pvc` привязан к `s3-pv-messager-dev-uploads`;
- загрузка файла создаёт объект в `messager-uploads` bucket;
- Argo CD показывает `Synced/Healthy` и включает `automated/prune/selfHeal`.
