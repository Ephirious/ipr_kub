# Отличия dev и prod overlays

## Dev

- Namespace: `messager-dev`
- Ingress host: `dev.messager.local`
- Реплики: по 1 для frontend, bff, user-service, message-service
- Resources: базовые requests/limits из `base`
- S3 PV: `s3-pv-messager-dev-uploads`
- MinIO endpoint для CSI: `http://minio.messager-dev.svc.cluster.local:9000`

## Prod

- Namespace: `messager-prod`
- Ingress host: `messager.example.com`
- Реплики: frontend, bff, user-service, message-service — по 2
- Resources: повышенные requests/limits через `patches/prod-replicas-resources.yaml`
- S3 PV: `s3-pv-messager-prod-uploads`
- MinIO endpoint для CSI: `http://minio.messager-prod.svc.cluster.local:9000`

## Образы

В учебном архиве README гарантирует готовые образы с тегом `latest`. Для настоящего production нужно заменить `latest` в `k8s/overlays/prod/kustomization.yaml` на immutable tag или digest вашего registry.

Пример получения digest после pull:

```bash
docker pull mablinov2704/frontend:latest
docker inspect --format='{{index .RepoDigests 0}}' mablinov2704/frontend:latest
```

Затем в prod overlay можно закрепить образ через digest.
