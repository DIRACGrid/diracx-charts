# Debugging

## Debug your production environment

### 1. Create a debugging branch
- Create a branch and add debugging content throughout the code.
- Push the branch to your VCS.

### 2. Retrieve `helm` values
- Retrieve the `helm` values of your production cluster:

```bash
helm get values <RELEASE_NAME> > values.yaml
```

### 3. Modify the values

**Apply a specific version of a diracx package**
- Edit the `values.yaml` file, such as:

```yaml
...
diracx:
  pythonModulesToInstall:
    - git+https://github.com/<YOUR_REPO>/diracx.git@<BRANCH_NAME>#&subdirectory=diracx-routers
    - git+https://github.com/<YOUR_REPO>/diracx.git@<BRANCH_NAME>#&subdirectory=diracx-db
    - ...
...
```

In this example, you install a specific version of `diracx-routers` and `diracx-db`.

**Apply a specific version of diracx-web**
- Edit the `values.yaml` file, such as:

```yaml
diracxWeb:
  repoURL: "https://github.com/<YOUR_REPO>/diracx-web"
  branch: "<YOUR_BRANCH>"
  ...
```

### 4. Upgrade the cluster
- Once done, upgrade your cluster:

```bash
cd diracx-charts/
helm upgrade <RELEASE_NAME> diracx/ -f <YOUR_UPDATED_VALUES>
```

*A new pod will be deployed and will contain your changes.*

### 5. Iteratively debug your environment

- Once your branch deployed, if you need to update your code, then make your changes, push the code to your VCS in the same branch, and restart the rollout of the pod.

```bash
kubectl rollout restart deployment/<POD_NAME>
```
