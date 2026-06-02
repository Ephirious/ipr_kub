# Задание по `kustomize`: `dev` и `prod`

## Цель

Собрать конфигурацию Kubernetes в формате:

- `base` - общие ресурсы
- `overlays/dev` - настройки для разработки
- `overlays/prod` - настройки для production

## Обязательная структура

```text
k8s/
  base/
    kustomization.yaml
    namespace.yaml
    configmap.yaml
    secret.example.yaml
    postgres.yaml
    postgres-pvc.yaml
    migrate-users-job.yaml
    migrate-messages-job.yaml
    user-service.yaml
    message-service.yaml
    bff.yaml
    frontend.yaml
    ingress.yaml
  overlays/
    dev/
      kustomization.yaml
      patches/
    prod/
      kustomization.yaml
      patches/
```

## Что должно отличаться между `dev` и `prod`

Минимум:

1. **Количество реплик**
   - dev: по 1 реплике
   - prod: `frontend`, `bff`, `user-service`, `message-service` >= 2
2. **Ресурсы контейнеров**
   - dev: базовые requests/limits
   - prod: повышенные requests/limits
3. **Ingress (опционально)**
   - если используете Ingress, должны быть разные host (`dev.messager.local` и `messager.example.com`)
4. **nodeAffinity**
   - в prod строго включены правила из задания по affinity
5. **Образы**
   - использовать одинаковые имена образов, но допускаются разные теги (`latest` для dev, фиксированный semver/sha для prod)

## Рекомендуемые механики `kustomize`

- `patches`/`patchesStrategicMerge` для изменения `replicas`, affinity и ресурсов
- `images` для подмены тегов образов
- `nameSuffix` (опционально для dev)
- `commonLabels` для трассировки окружения
- `configMapGenerator` и `secretGenerator` (если это согласуется с вашей политикой)

## Проверка сборки

```bash
kustomize build k8s/overlays/dev
kustomize build k8s/overlays/prod
```

Обе команды должны выдавать валидный итоговый YAML.

## Что сдать по этой части

- полный каталог `k8s/base` и `k8s/overlays/{dev,prod}`
- доказательство, что оба overlay собираются
- короткий `docs`-файл с перечислением отличий dev/prod

## Критерии оценки

- корректная модульность (без дублирования одинаковых манифестов в overlay)
- явные и осмысленные различия между dev/prod
- собираемость и валидность обоих overlay
