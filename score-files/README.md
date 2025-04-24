Below, I’ll guide you through integrating a **Service Catalog** with Backstage using the YAML `score` files from your example, deploying it with the **Humanitec `humctl` tool**, and creating a **Backstage template** for the sample app. I’ll also provide an exercise for your workshop participants to follow. The focus will be on registering the sample app in Backstage’s Service Catalog right after deployment and creating a reusable template.

Since you’re using Humanitec, I’ll adapt the process to leverage its platform orchestration capabilities, ensuring Backstage and the sample app are deployed via Humanitec’s Score integration.

---

### Prerequisites
- **Humanitec Account:** Ensure you have an organization and project set up in Humanitec.
- **Humanitec CLI (`humctl`):** Installed and authenticated (`humctl login`).
- **Local Kubernetes Cluster:** Minikube or Kind running.
- **Score CLI:** Installed (`npm install -g @score-spec/score-cli`).
- **Workshop Files:** Use the `backstage-score.yaml` and `sample-app-score.yaml` from my previous response.

---

### Step 1: Deploy Backstage with Humanitec
Humanitec supports Score files for workload definitions. We’ll deploy Backstage and configure its Service Catalog to include the sample app.

#### 1.1. Deploy Backstage
1. **Prepare the Score File:**
   - Use `backstage-score.yaml` from the previous example (ensure it’s in `score-files/`).

2. **Create a Humanitec Application:**
   ```bash
   humctl create app backstage-workshop
   ```

3. **Deploy Backstage via Score:**
   - Humanitec uses Score to generate manifests. Run:
     ```bash
     humctl score deploy -f score-files/backstage-score.yaml --app-id backstage-workshop --env dev
     ```
   - This deploys Backstage with its PostgreSQL database to your local cluster (assuming it’s registered with Humanitec).

4. **Access Backstage:**
   - Forward the port to verify:
     ```bash
     kubectl port-forward svc/backstage-workshop 7007:80
     ```
   - Open `http://localhost:7007`. You should see the Backstage UI.

#### 1.2. Configure the Service Catalog
To register the sample app in Backstage’s catalog immediately after deployment, we’ll use a `catalog-info.yaml` file and configure Backstage to read it.

1. **Create `catalog-info.yaml` for the Sample App:**
   Save this in `score-files/` as `catalog-info.yaml`:
   ```yaml
   apiVersion: backstage.io/v1alpha1
   kind: Component
   metadata:
     name: workshop-sample-app
     description: A sample app for the Backstage workshop
     annotations:
       humanitec.com/app-id: sample-app-workshop  # Links to Humanitec app
   spec:
     type: service
     lifecycle: experimental
     owner: workshop-team
     system: workshop-system
   ```

2. **Update Backstage Configuration:**
   - Backstage needs to know where to find catalog files. Since Humanitec manages the deployment, we’ll use a ConfigMap to inject this configuration.
   - Create `backstage-config.yaml`:
     ```yaml
     apiVersion: v1
     kind: ConfigMap
     metadata:
       name: backstage-config
       namespace: default  # Adjust if using a different namespace
     data:
       app-config.yaml: |
         app:
           title: Backstage Workshop
           baseUrl: http://localhost:7007
         backend:
           baseUrl: http://localhost:7007
           cors:
             origin: http://localhost:7007
         catalog:
           locations:
             - type: file
               target: /config/catalog-info.yaml
     ```
   - Apply it:
     ```bash
     kubectl apply -f backstage-config.yaml
     ```

3. **Mount the Catalog File:**
   - Modify `backstage-score.yaml` to mount `catalog-info.yaml` into the Backstage container:
     ```yaml
     apiVersion: score.dev/v1b1
     metadata:
       name: backstage-workshop
     service:
       ports:
         backstage:
           port: 80
           targetPort: 7007
     containers:
       backstage:
         image: ghcr.io/backstage/backstage:latest
         variables:
           PORT: "7007"
           NODE_ENV: "development"
           POSTGRES_HOST: ${resources.db.host}
           POSTGRES_PORT: ${resources.db.port}
           POSTGRES_USER: ${resources.db.username}
           POSTGRES_PASSWORD: ${resources.db.password}
           POSTGRES_DB: ${resources.db.name}
         volumes:
           - source: configmap://backstage-config
             target: /app/config
           - source: file://catalog-info.yaml
             target: /config/catalog-info.yaml
     resources:
       dns:
         type: dns
       route:
         type: route
         params:
           host: ${resources.dns.host}
           path: /
           port: 80
       db:
         type: postgres
         params:
           name: backstage_db
           username: backstage_user
           password: supersecret123
     ```
   - Redeploy:
     ```bash
     humctl score deploy -f score-files/backstage-score.yaml --app-id backstage-workshop --env dev
     ```

4. **Verify Catalog:**
   - Reload `http://localhost:7007/catalog`. You should see “workshop-sample-app” listed.

---

### Step 2: Deploy the Sample App
1. **Create a Humanitec Application:**
   ```bash
   humctl create app sample-app-workshop
   ```

2. **Deploy the Sample App:**
   - Use `sample-app-score.yaml`:
     ```bash
     humctl score deploy -f score-files/sample-app-score.yaml --app-id sample-app-workshop --env dev
     ```

3. **Access the Sample App:**
   ```bash
   kubectl port-forward svc/workshop-sample-app 8080:8080
   ```
   - Open `http://localhost:8080` to see “Welcome to the Backstage Workshop!”.

---

### Step 3: Create a Backstage Template
We’ll create a template based on the sample app so workshop participants can scaffold new instances.

1. **Create `template.yaml`:**
   Save this in `score-files/`:
   ```yaml
   apiVersion: backstage.io/v1alpha1
   kind: Template
   metadata:
     name: workshop-sample-app-template
     title: Workshop Sample App Template
     description: Creates a simple app with Postgres and Redis for the workshop
   spec:
     owner: workshop-team
     type: service
     parameters:
       - title: App Name
         required: true
         type: string
         name: appName
       - title: Welcome Message
         required: true
         type: string
         name: message
     steps:
       - id: generate-score
         name: Generate Score File
         action: fetch:template
         input:
           url: ./skeleton
           values:
             appName: ${{ parameters.appName }}
             message: ${{ parameters.message }}
   ```

2. **Create the Skeleton Score File:**
   Save this as `score-files/skeleton/sample-app-score.yaml`:
   ```yaml
   apiVersion: score.dev/v1b1
   metadata:
     name: ${appName}
   service:
     ports:
       www:
         port: 8080
         targetPort: 3000
   containers:
     sample-app:
       image: ghcr.io/score-spec/sample-score-app:latest
       variables:
         PORT: "3000"
         MESSAGE: ${message}
         DB_DATABASE: ${resources.db.name}
         DB_USER: ${resources.db.username}
         DB_PASSWORD: ${resources.db.password}
         DB_HOST: ${resources.db.host}
         DB_PORT: ${resources.db.port}
         REDIS_HOST: ${resources.cache.host}
         REDIS_PORT: ${resources.cache.port}
   resources:
     dns:
       type: dns
     route:
       type: route
       params:
         host: ${resources.dns.host}
         path: /
         port: 8080
     db:
       type: postgres
       params:
         name: ${appName}-db
         username: ${appName}-user
         password: workshop456
     cache:
       type: redis
       params:
         version: "6.2"
   ```

3. **Register the Template in Backstage:**
   - Add the template to Backstage’s catalog:
     ```yaml
     apiVersion: backstage.io/v1alpha1
     kind: Location
     metadata:
       name: workshop-templates
       description: Templates for the workshop
     spec:
       targets:
         - ./template.yaml
     ```
   - Mount this into Backstage by updating `backstage-config.yaml`:
     ```yaml
     catalog:
       locations:
         - type: file
           target: /config/catalog-info.yaml
         - type: file
           target: /config/template.yaml
     ```
   - Redeploy Backstage with the updated ConfigMap and template file mounted.

---

### Workshop Exercise

#### Title: Deploy and Manage a Sample App with Backstage
**Objective:** Deploy Backstage, register a sample app in its Service Catalog, and use a template to create a new app instance.

#### Steps:
1. **Setup Environment:**
   - Start Minikube: `minikube start`
   - Install `humctl` and log in: `humctl login`
   - Clone the workshop repo: `git clone <repo-url> && cd backstage-workshop`

2. **Deploy Backstage:**
   - Create the app: `humctl create app backstage-workshop`
   - Deploy: `humctl score deploy -f score-files/backstage-score.yaml --app-id backstage-workshop --env dev`
   - Access: `kubectl port-forward svc/backstage-workshop 7007:80`
   - Open `http://localhost:7007` and explore the UI.

3. **Verify the Service Catalog:**
   - Navigate to the “Catalog” tab.
   - Confirm “workshop-sample-app” is listed (from `catalog-info.yaml`).

4. **Deploy the Sample App:**
   - Create the app: `humctl create app sample-app-workshop`
   - Deploy: `humctl score deploy -f score-files/sample-app-score.yaml --app-id sample-app-workshop --env dev`
   - Access: `kubectl port-forward svc/workshop-sample-app 8080:8080`
   - Visit `http://localhost:8080` and note the welcome message.

5. **Create a New App with the Template:**
   - In Backstage, go to “Create” (http://localhost:7007/create).
   - Select “Workshop Sample App Template”.
   - Enter:
     - App Name: `my-sample-app`
     - Welcome Message: `Hello from my app!`
   - Click “Next” and “Create”. Backstage generates a new Score file.
   - Deploy it with Humanitec:
     ```bash
     humctl score deploy -f my-sample-app-score.yaml --app-id my-sample-app --env dev
     ```
   - Access: `kubectl port-forward svc/my-sample-app 8080:8080`
   - Verify the message at `http://localhost:8080`.

6. **Bonus: Add to Catalog:**
   - Create a `catalog-info.yaml` for `my-sample-app` and mount it into Backstage (repeat Step 1.2).

#### Deliverables:
- Screenshot of the Backstage catalog showing both apps.
- URL output of `my-sample-app` with its custom message.

---

### Notes
- **Humanitec Integration:** Ensures Backstage and the sample app are managed as part of a platform workflow.
- **Catalog Automation:** The initial catalog entry is static; for dynamic discovery, use Backstage’s Kubernetes plugin.
- **Template Flexibility:** The template allows customization, making it workshop-friendly.



To forward traffic from your localhost to the Ingress controller in Kubernetes using `kubectl port-forward`, follow these steps:

---

### **1. Find the Ingress Controller's Service**
Since `kubectl port-forward` works with **Pods** or **Services**, you need to find the **Ingress controller service**.

Run:
```sh
kubectl get svc -n ingress-nginx
```
You should see output similar to:
```
NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.96.81.107    <none>        80:31611/TCP, 443:31612/TCP   12m
```

If the Ingress Controller service name is different, update the following commands accordingly.

---

### **2. Port Forward the Ingress Service**
To access your Backstage instance via **http://5min-backstage-qksi-w2yt.localhost**, forward **port 80** from the ingress controller:

```sh
kubectl port-forward svc/ingress-nginx-controller 8080:80 -n ingress-nginx
```
Now, your ingress can be accessed at:
```
http://localhost:8080
```

---

### **3. Automatically Open in Browser (Zsh)**
In **Zsh**, you can open the URL automatically with:

```sh
kubectl port-forward svc/ingress-nginx-controller 8080:80 -n ingress-nginx & sleep 2 && open http://5min-backstage-qksi-w2yt.localhost:8080
```

For Linux (with `xdg-open`):
```sh
kubectl port-forward svc/ingress-nginx-controller 8080:80 -n ingress-nginx & sleep 2 && xdg-open http://5min-backstage-qksi-w2yt.localhost:8080
```
or 
```sh
  k - n ingress-nginx port-forward pods/ingress-nginx-controller-6647957864-cnbw5 8081:443
```
---

### **Alternative: Use `hostAliases` (if DNS resolution fails)**
If `5min-backstage-qksi-w2yt.localhost` doesn’t resolve, update `/etc/hosts`:
```sh
echo "127.0.0.1 5min-backstage-qksi-w2yt.localhost" | sudo tee -a /etc/hosts
```

---

### **Now, you can access Backstage at:**
```
http://5min-backstage-qksi-w2yt.localhost:8081
```

Would you like an automated script for this? 🚀