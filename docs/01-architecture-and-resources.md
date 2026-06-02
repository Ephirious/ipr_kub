# Архитектура и ресурсы Kubernetes

## 1. Состав приложения

Приложение состоит из следующих компонентов:

- `frontend` (nginx + SPA), внешний вход в систему
- `bff` (Backend For Frontend), агрегирует API
- `user-service`, работа с пользователями
- `message-service`, работа с сообщениями и файлами
- `postgres`, единый инстанс БД с двумя БД внутри (`messager_users`, `messager_messages`)
- `migrate-users`, `migrate-messages` (job для применения миграций)

## 2. Какие ресурсы Kubernetes нужны

Минимально необходимый набор:

- `Namespace` - изоляция лабораторного окружения
- `Deployment` - для `frontend`, `bff`, `user-service`, `message-service`, `postgres`, (опционально `minio`)
- `Service` - внутренняя DNS-связность между сервисами
- `Ingress` (опционально) - внешний вход для `frontend`, если нужен домен/HTTP-маршрутизация
- `ConfigMap` - несекретная конфигурация (порты, URL, пути)
- `Secret` - чувствительные данные (пароли БД, ключи S3)
- `Job` - миграции БД (`goose`)
- `PersistentVolumeClaim` - хранилище БД (и при необходимости MinIO)
- `StorageClass`/`PV` (опционально, если нет default storage class)
- `ServiceAccount`/`Role`/`RoleBinding` (опционально, если ограничиваете доступ)

Для S3 через CSI:

- `Secret` с credentials
- `PersistentVolume` + `PersistentVolumeClaim` (если CSI-драйвер работает через static provisioning)
- CSI-специфичные параметры в `volumeAttributes` (bucket, endpoint, region, mounter, префикс)

Для GitOps:

- `Application` Argo CD
- (опционально) `AppProject`

## 3. Сетевые связи

- Внешний трафик: `Ingress -> frontend` (опционально, можно использовать `NodePort`/`LoadBalancer`)
- Внутренний API:
  - `frontend -> bff` (через internal URL или через same-origin proxy)
  - `bff -> user-service`
  - `bff -> message-service`
  - `user-service -> postgres`
  - `message-service -> postgres`

## 4. Конфигурация сервисов (что вынести в ConfigMap/Secret)

### `bff`

- `HTTP_PORT=8080`
- `USER_SERVICE_URL=http://user-service:8081`
- `MSG_SERVICE_URL=http://message-service:8082`

### `user-service`

- `HTTP_PORT=8081`
- `DB_DSN` (в `Secret`)

### `message-service`

- `HTTP_PORT=8082`
- `DB_DSN` (в `Secret`)
- `UPLOADS_DIR=/app/uploads`

### `frontend`

- `BFF_URL` (обычно пусто при same-origin)
- `BFF_INTERNAL_URL=http://bff:8080`

### `postgres`

- `POSTGRES_USER` (Secret)
- `POSTGRES_PASSWORD` (Secret)
- `POSTGRES_DB=messager` (ConfigMap или Secret)

## 5. Рекомендуемые probes и requests/limits

Для `Deployment`:

- `readinessProbe`: HTTP GET на health endpoint (или `/` для frontend)
- `livenessProbe`: HTTP GET на тот же endpoint с более мягкими таймингами
- `resources.requests` и `resources.limits` обязательны хотя бы в prod overlay

Минимальные ориентиры (dev):

- `frontend`: `100m/128Mi`
- `bff`, `user-service`, `message-service`: `150m/192Mi`
- `postgres`: `250m/512Mi`

## 6. Порядок запуска

1. Namespace, ConfigMap/Secret, PVC
2. Postgres Deployment/Service
3. Job миграций
4. Backend Deployments/Services
5. Frontend Deployment/Service (Ingress - опционально)
6. Проверка доступности
