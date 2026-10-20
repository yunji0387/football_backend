# Football backend on the area87 Kubernetes cluster

This runbook deploys the football backend and PostgreSQL into the existing
single-node k3s cluster described in the homelab Kubernetes repository at
`C:\Users\yunji\code\k8s`. It uses the existing `homelab` namespace, k3s
local-path storage, and the cluster's Traefik ingress. PostgreSQL is only
available inside the cluster. Public/API access is optional and should use the
existing Cloudflare Tunnel and Zero Trust setup.

## Deployment constraints

- The area87 cluster is currently a single node. PVCs use k3s local-path
  storage and are tied to that node; they are not replicated backups.
- Run one backend replica. The application schedules provider syncs in each
  running instance, so multiple replicas would duplicate scheduled work.
- The repository's current Dockerfile and entrypoint are a development-oriented
  image (`mix phx.server`, dependency fetch, and migrations at container start),
  not a hardened Phoenix production release. The steps below deploy that
  existing image for a private homelab service. Do not expose it publicly until
  a production release and suitable HTTPS/public-access review are in place.
- The app entrypoint waits for PostgreSQL and applies Ecto migrations before
  starting Phoenix. Keep the app at one replica during upgrades and migrations.

## 1. Connect to area87 and prepare the namespace

Run these commands from the machine where the area87 kubeconfig is configured.
Confirm the selected context and node before applying anything:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get namespace homelab
```

If `homelab` does not exist yet, apply the cluster namespace file from the k8s
repository (it also declares the existing MetalLB pool and advertisement):

```bash
cd ~/k8s
kubectl apply -f clusters/area87/namespaces.yaml
```

The expected namespace is `homelab`. Do not apply this guide's resources to a
different cluster context by mistake.

## 2. Build and import the application image

Build on the Ubuntu k3s server (or on a compatible Linux/amd64 builder), using a
unique image tag. The current Dockerfile is not a multi-architecture build.
Building on the k3s server avoids transferring the source image between hosts:

```bash
cd ~/apps/football_backend
git pull
sudo docker build -t football-backend:2026-10-18 .
sudo docker save football-backend:2026-10-18 -o /tmp/football-backend.tar
sudo k3s ctr images import /tmp/football-backend.tar
sudo k3s crictl images | grep football-backend
```

Use the same tag in the Deployment manifest below. k3s uses containerd, so an
image built only into Docker is not automatically visible to Kubernetes; the
`ctr images import` step is required. Remove the temporary archive after the
import if desired. For repeatable CI deployments, publish the image to a private
container registry and configure `imagePullSecrets` instead.

## 3. Create credentials and application configuration

Create the database and provider credentials as a Kubernetes Secret directly
on the trusted administration machine. Do not save a Secret manifest or place
actual credentials in Git. `API_SPORT_FOOTBALL_API_KEY` is needed for the
primary provider; the football-data.org token and Telegram credentials are
optional.

```bash
kubectl -n homelab create secret generic football-backend-secret \
  --from-literal=DB_PASSWORD='replace-with-a-long-random-password' \
  --from-literal=API_SPORT_FOOTBALL_API_KEY='your-api-football-key' \
  --from-literal=FOOTBALL_DATA_TOKEN='' \
  --from-literal=TELEGRAM_BOT_TOKEN='' \
  --from-literal=TELEGRAM_CHAT_ID='' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Use a generated unique password and shell-safe quoting. For values with shell
special characters, create the Secret from a protected temporary env file and
delete that file after use. `FOOTBALL_SEASON` may be empty to select the
application's current-season behavior. Choose an explicit season if the
provider key has limited season access.

Create the non-secret settings:

```bash
kubectl -n homelab create configmap football-backend-config \
  --from-literal=DB_USERNAME=postgres \
  --from-literal=DB_HOSTNAME=football-backend-db \
  --from-literal=DB_NAME=football_backend_dev \
  --from-literal=FOOTBALL_COMPETITION=PL \
  --from-literal=FOOTBALL_SEASON='' \
  --from-literal=MIX_ENV=dev \
  --dry-run=client -o yaml | kubectl apply -f -
```

League `PL` selects the Premier League. Re-run these commands to update values;
after changing a Secret or ConfigMap, restart the backend Deployment to load the
new environment.

## 4. Deploy PostgreSQL and the backend

The following manifest is stored in the k8s repository at
`clusters/area87/homelab/football-backend/football-backend-k8s.yaml` (alongside
the other homelab apps); apply it from `~/k8s`. Secrets are never committed.
The 10 GiB database PVC uses the cluster's default local-path StorageClass. The
PostgreSQL Deployment has one replica and a persistent data volume. The app
Service is cluster-internal; an Ingress is added in the next section only if
you want HTTP routing through the existing tunnel.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: football-backend-db-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: football-backend-db
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: football-backend-db
  template:
    metadata:
      labels:
        app: football-backend-db
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - name: postgres
              containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_DB
              value: football_backend_dev
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: football-backend-secret
                  key: DB_PASSWORD
          readinessProbe:
            exec:
              command: ["sh", "-c", "pg_isready -U postgres -d football_backend_dev"]
            initialDelaySeconds: 5
            periodSeconds: 10
          volumeMounts:
            - name: database
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: database
          persistentVolumeClaim:
            claimName: football-backend-db-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: football-backend-db
  namespace: homelab
spec:
  selector:
    app: football-backend-db
  ports:
    - name: postgres
      port: 5432
      targetPort: postgres
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: football-backend
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: football-backend
  template:
    metadata:
      labels:
        app: football-backend
    spec:
      containers:
        - name: app
          image: football-backend:2026-10-18
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 4000
          envFrom:
            - configMapRef:
                name: football-backend-config
            - secretRef:
                name: football-backend-secret
          readinessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 60
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: football-backend
  namespace: homelab
spec:
  selector:
    app: football-backend
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply it and wait for both deployments:

```bash
kubectl apply -f ~/k8s/clusters/area87/homelab/football-backend/football-backend-k8s.yaml
kubectl rollout status deployment/football-backend-db -n homelab --timeout=5m
kubectl rollout status deployment/football-backend -n homelab --timeout=10m
kubectl get pods,pvc,svc -n homelab -l 'app in (football-backend,football-backend-db)'
kubectl logs -n homelab deployment/football-backend --tail=150
```

The first database initialization and application dependency startup can take a
few minutes. Check the logs for migration completion and provider/API errors.
An empty provider key disables API-Football sync; the app can still serve local
API data.

## 5. Verify access

First verify through port forwarding from the machine running `kubectl`:

```bash
kubectl port-forward -n homelab service/football-backend 4000:80
```

In another terminal:

```bash
curl -fsS http://127.0.0.1:4000/api/health
curl -fsS 'http://127.0.0.1:4000/api/standings?league_id=39'
```

The in-cluster PostgreSQL Service is `football-backend-db.homelab.svc.cluster.local:5432`.
There is intentionally no LoadBalancer or NodePort for PostgreSQL.

## 6. Optional access through area87 Cloudflare Tunnel

Only add an Ingress if the API should be reachable at a hostname. The area87
repository documents Cloudflare Tunnel to Traefik and Zero Trust Access; it
currently does not list a football backend hostname. Pick a hostname such as
`football-optiplex.area87.uk`, then:

1. Add a Cloudflare Tunnel public hostname for that DNS name, pointing to
   `http://localhost:80`, matching the other Traefik-routed apps.
2. Add the hostname to the host's `/etc/cloudflared/config.yml` if required by
   the current tunnel configuration, then restart `cloudflared`.
3. Add a Cloudflare Zero Trust self-hosted Access application and an allow policy
   for your account before relying on the public hostname.
4. Apply an Ingress routing the hostname to service `football-backend`, port 80:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: football-backend-ingress
  namespace: homelab
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: football-optiplex.area87.uk
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: football-backend
                port:
                  number: 80
```

The Ingress is stored as
`clusters/area87/homelab/football-backend/football-backend-ingress.yaml` in the
k8s repository; apply it with `kubectl apply -f`. The
Tunnel terminates the external connection at Cloudflare and sends HTTP to
Traefik inside the home network as documented by the k8s repository. Keep
Cloudflare Access in front of this development-oriented app.

## 7. Updates, backups, and recovery

Before an image update or migration, back up PostgreSQL:

```bash
kubectl exec -n homelab deployment/football-backend-db -- \
  sh -c 'pg_dump -U postgres football_backend_dev' > football_backend_$(date +%F_%H%M%S).sql
```

Build and import a new uniquely tagged image using step 2. Change the image tag
in the manifest, then apply it and watch the rollout:

```bash
kubectl apply -f ~/k8s/clusters/area87/homelab/football-backend/football-backend-k8s.yaml
kubectl rollout status deployment/football-backend -n homelab --timeout=10m
kubectl logs -n homelab deployment/football-backend --tail=150
```

Keep database backups off the cluster node and periodically verify restoration.
The local-path PVC survives pod replacement but not loss of the node or its
disk. Avoid deleting `football-backend-db-pvc` during cleanup; deleting it can
delete the only live database copy. Restore a dump into PostgreSQL before
restarting the app if recovery is needed.

## Troubleshooting

- **Pod is `ImagePullBackOff`:** confirm the image was imported into k3s
  containerd and that its tag exactly matches the Deployment.
- **App is waiting for PostgreSQL:** check `kubectl get pods,svc -n homelab`
  and the database logs; verify both pods use the same namespace and Secret.
- **App restarts during first boot:** inspect app logs for dependency, database,
  or migration errors. The entrypoint requires a reachable database before
  launching Phoenix.
- **Health probe fails:** inspect app logs and confirm `/api/health` returns
  success using port-forwarding.
- **Provider sync fails or returns no records:** check the key, selected season,
  provider quota/access, and logs. Sync runs about one minute after startup and
  then every six hours; operational details are in [sync operations](sync-operations.md).
- **Hostname does not resolve or route:** check the Cloudflare Tunnel hostname,
  DNS/Access configuration, Ingress host, Traefik, and service endpoints.
