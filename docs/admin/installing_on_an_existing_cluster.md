# Install diracx on a running cluster

## Rancher cluster


1. Verify existing resources:
    - `cert-manager`: 
        ```
        kubectl get cert-manager
        NAME                                               READY   AGE
        clusterissuer.cert-manager.io/letsencrypt-issuer   True    2y211d
        ```
    - `ingress`:
        ```
        kubectl get ingressClass -A
        NAME    CONTROLLER             PARAMETERS   AGE
        nginx   k8s.io/ingress-nginx   <none>       623d
        ```
    - `external-dns`:
        ```
        kubectl get deployments -n external-dns
        NAME           READY   UP-TO-DATE   AVAILABLE   AGE
        external-dns   1/1     1            1           2y187d
        ```
    - `storageClass`:
        ```
        kubectl get storageclass
        NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
        longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   263d
        ```

2. Adapting the charts:
    - `storageClass`: you should simply replace the `global.storageClass=<storage_class_name>` by the existing one.

    - `cert-manager`: if you want to use the existing cluster issuer, disable the `cert-manager` in the values (`cert-manager.enabled=False`) then create a new `Certificate` resource in the issuer chart (`charts > cert-manager-issuer > _issuer.yaml`):

        ```
        {{- if index .Values "cluster-issuer" "enabled" }}
        apiVersion: cert-manager.io/v1
        kind: Certificate
        metadata:
        name: diracx-ca
        spec:
        dnsNames:
            {{- range index .Values "cluster-issuer" "dnsNames" }}
            - {{ . }}
            {{- end }}
        secretName: root-secret
        commonName: diracx-ca
        privateKey:
            algorithm: ECDSA
            size: 256
        issuerRef:
            name: letsencrypt-issuer
            kind: ClusterIssuer
        {{- end }}

        ```
        Define the following in the `charts > cert-manager-issuer > values.yaml`
        ```
        cluster-issuer:
            enabled: true
            dnsNames:
                - vault.cta-test.zeuthen.desy.de
        ```
        Then remove the usage of the  `diracx-ca-issuer` in the ingress definition anotations:
        ```
        kind: Ingress
        metadata:
        name: {{ $fullName }}
        labels:
            {{- include "diracx.labels" . | nindent 4 }}
        annotations:
        # {{- if index .Values "cert-manager-issuer" "enabled" }}
        #   cert-manager.io/issuer: diracx-ca-issuer
        # {{- end }}
        ```
        Finally specify the use the cluster issuer: `ingress.annotations.cert-manager.io/cluster-issuer=<cluster-issuer-name>`
    
    - `ingress`:
        - simply replace: `ingress.className` by the existing one.
        - using an [external-dns](https://github.com/kubernetes-sigs/external-dns) service:
            - the external-dns service should use a prefered IP (probably provided by a [kube-vip](https://kube-vip.io/) service):
                - `ingress.annotations.external-dns.alpha.kubernetes.io/hostname=<hostname>`
                - `ingress.annotations.external-dns.alpha.kubernetes.io/target: <static-ip>`
                - `ingress.annotations.kubernetes.io/tls-acme="true"`
                - `ingress.loadBalancerIP=<static-ip>` 
    