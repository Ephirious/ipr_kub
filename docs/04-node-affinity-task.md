# Задание по `nodeAffinity`

## Сценарий

В кластере есть 2 класса узлов:

- `workload=system` - системные и инфраструктурные сервисы
- `workload=app` - прикладные сервисы

Дополнительно часть `app`-узлов помечена как `disk=fast`.

## Требование

Настройте scheduling так, чтобы:

1. `postgres` и `minio` запускались **только** на `workload=system`.
2. `frontend`, `bff`, `user-service` запускались **только** на `workload=app`.
3. `message-service` запускался на `workload=app`, и приоритетно на `disk=fast`.
4. Если `disk=fast` недоступен, `message-service` должен запускаться на любом `workload=app`.

## Пример меток узлов

```bash
kubectl label node <node-1> workload=system
kubectl label node <node-2> workload=app
kubectl label node <node-3> workload=app disk=fast
```

## Пример `requiredDuringSchedulingIgnoredDuringExecution`

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values:
                - app
```

## Пример `preferredDuringSchedulingIgnoredDuringExecution`

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values: ["app"]
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: disk
              operator: In
              values: ["fast"]
```

## Что сдать по этой части

- YAML (или patch в kustomize), где видно `nodeAffinity` для всех требуемых Deployments
- вывод `kubectl get pods -o wide -n messager`
- вывод `kubectl describe pod <pod-name> -n messager` (фрагмент с `Node-Selectors/Affinity`)

## Критерии оценки

- корректно соблюдены ограничения по типам узлов
- `message-service` имеет hard requirement по `workload=app` и soft preference по `disk=fast`
- решения реализованы через `affinity`, а не только через `nodeSelector`
