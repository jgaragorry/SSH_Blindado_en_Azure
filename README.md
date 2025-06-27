<div align="center">
  <img src="https://placehold.co/600x200/1e293b/ffffff?text=Laboratorio+de+Blindaje+SSH" alt="Banner del Laboratorio de Blindaje SSH en Azure">
</div>

<h1 align="center">Laboratorio Práctico: Blindaje de SSH en Azure</h1>

Este repositorio contiene una guía detallada y un conjunto de scripts para demostrar el proceso manual de "hardening" (blindaje) de un servicio SSH en una máquina virtual Ubuntu desplegada en Azure.

El objetivo es transformar una configuración por defecto, que permite el acceso por contraseña a través del puerto 22, en una configuración segura y profesional que exige el uso de llaves criptográficas a través de un puerto no estándar.

---

## 📋 Tabla de Contenido

- [🎯 **Objetivo del Laboratorio**](#-objetivo-del-laboratorio)
- [🛠️ **Requisitos Previos**](#-requisitos-previos)
- [📂 **Contenido del Repositorio**](#-contenido-del-repositorio)
- [🚀 **Guía de Ejecución Paso a Paso**](#-guía-de-ejecución-paso-a-paso)
  - [Fase 1: Despliegue del Entorno](#fase-1-despliegue-del-entorno-de-laboratorio)
  - [Fase 2: Preparación y Acceso Inicial](#fase-2-preparación-y-acceso-inicial)
  - [Fase 3: Hardening Manual DENTRO de la VM](#fase-3-hardening-manual-dentro-de-la-vm)
  - [Fase 4: Actualización de Reglas de Red en Azure](#fase-4-actualización-de-reglas-de-red-en-azure)
  - [Fase 5: Verificación Final del Blindaje](#fase-5-verificación-final-del-blindaje)
  - [Fase Final: Limpieza de Recursos](#fase-final-limpieza-del-entorno)
- [📜 **Código Completo de los Scripts**](#-código-completo-de-los-scripts)

---

## 🎯 Objetivo del Laboratorio

Este laboratorio está diseñado para que los profesionales de TI y ciberseguridad puedan:

- **Comprender** las debilidades de una configuración SSH por defecto.
- **Implementar** la autenticación basada en llaves, el método más seguro.
- **Modificar** el puerto de escucha de SSH para reducir la exposición a ataques automatizados.
- **Configurar** correctamente tanto el firewall del sistema operativo (`UFW`) como las reglas de red de Azure (NSG).

---

## 🛠️ Requisitos Previos

Antes de comenzar, asegúrate de tener lo siguiente en tu máquina local (ej. WSL):

| Herramienta | Comando de Verificación / Instalación | Propósito |
| :--- | :--- | :--- |
| **Azure CLI** | `az version` | Para interactuar con tu suscripción de Azure. |
| **Cliente SSH** | `ssh -V` | Para conectarse a la máquina virtual. |
| **`jq`** | `sudo apt install jq` | Para procesar la salida JSON de Azure CLI. |

> **Nota Importante:** Debes haber iniciado sesión en Azure CLI antes de ejecutar los scripts. Usa el comando `az login`.

---

## 📂 Contenido del Repositorio

| Script | Descripción |
| :--- | :--- |
| 📜 `create_vm.sh` | Despliega la VM Ubuntu 24.04 vulnerable en Azure. |
| 🔍 `verify_vm.sh` | Verifica el estado y obtiene los detalles de la VM. |
| 🧹 `delete_resources.sh` | Elimina todos los recursos de Azure y espera a que el proceso finalice. |

---

## 🚀 Guía de Ejecución Paso a Paso

### **Fase 1: Despliegue del Entorno de Laboratorio**

**Ubicación:** Tu terminal local (WSL `gmt@MSI`).

1.  **Crear la VM:** Ejecuta el script para desplegar el servidor Ubuntu en Azure.
    ```bash
    ./create_vm.sh
    ```
2.  **Verificar y Obtener IP:** Una vez que termine, ejecuta el script de verificación para obtener la dirección IP pública. **Anota esta IP**, la necesitarás para todo lo demás.
    ```bash
    ./verify_vm.sh
    ```

### **Fase 2: Preparación y Acceso Inicial**

1.  **Obtener tu Llave Pública (En tu WSL Local):** Necesitamos tu llave pública para autorizarla en el servidor. Ejecuta este comando para mostrarla en pantalla.
    ```bash
    cat ~/.ssh/id_rsa.pub
    ```
    **Copia toda la línea de salida** (que empieza con `ssh-rsa AAAA...`). Mantenla en tu portapapeles.

2.  **Conectarse a la VM Vulnerable (Desde tu WSL Local):** Usa la IP del paso anterior para conectarte por primera (y última) vez con contraseña.
    ```bash
    ssh gmt@<TU_IP_PÚBLICA>
    ```
    *Usa la contraseña `Password1234!`.*

### **Fase 3: Hardening Manual DENTRO de la VM**

**Ubicación:** DENTRO de la VM de Azure (en la sesión SSH que acabas de abrir).

1.  **Instalar tu Llave Pública:**
    ```bash
    # Crear el directorio y el archivo de llaves autorizadas
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    
    # Abrir el archivo con el editor nano
    nano ~/.ssh/authorized_keys 
    
    # Dentro de nano, pega la llave pública que copiaste en la Fase 2.
    # Guarda y cierra (Ctrl+X, luego Y, luego Enter).
    ```

2.  **Corregir Permisos (¡Paso Crítico!):** SSH no aceptará la llave si los permisos son incorrectos.
    ```bash
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    ```

3.  **Modificar la Configuración del Servicio SSH:**
    ```bash
    sudo nano /etc/ssh/sshd_config
    ```
    Dentro del archivo, busca y modifica estas tres líneas (elimina el `#` si lo tienen):
    - Cambia `#Port 22` a `Port 2222`
    - Cambia `PasswordAuthentication yes` a `PasswordAuthentication no`
    - Cambia `#PermitRootLogin prohibit-password` a `PermitRootLogin no`

4.  **Validar la Configuración de SSH:** Antes de reiniciar, asegúrate de que no hay errores de sintaxis.
    ```bash
    sudo sshd -t
    ```
    *Si este comando no muestra nada, la configuración es correcta.*

5.  **Configurar el Firewall Interno (UFW):**
    ```bash
    sudo ufw allow 2222/tcp
    ```

6.  **Reiniciar el Servicio SSH:** Este es el punto de no retorno. Tu conexión actual se cortará.
    ```bash
    sudo systemctl restart ssh
    ```
    > **¡Es normal y esperado que tu sesión SSH se congele o se cierre en este momento!**
    >
    > **Nota Opcional:** Si por alguna razón tu conexión no se corta, puedes forzar que todos los servicios se recarguen con un reinicio completo de la VM. Ejecuta `sudo reboot`. Ten en cuenta que la VM tardará 1-2 minutos en volver a estar disponible.

### **Fase 4: Actualizar Reglas de Red en Azure**

**Ubicación:** Tu terminal local (WSL `gmt@MSI`).

1.  **Abrir el nuevo puerto 2222 en el firewall de Azure:**
    ```bash
    az vm open-port --resource-group rg-gmt-vm-lab --name vm-gmt-ubuntu --port 2222 --priority 900
    ```
2.  **Cerrar el puerto inseguro 22 (muy recomendado):**
    ```bash
    az network nsg rule delete --resource-group rg-gmt-vm-lab --nsg-name vm-gmt-ubuntuNSG --name default-allow-ssh
    ```
3.  **(Paso Opcional pero Recomendado) Verificación en el Portal de Azure:**
    > Antes de intentar la nueva conexión, es una excelente práctica ir al **Portal de Azure**, navegar a tu grupo de recursos (`rg-gmt-vm-lab`), seleccionar el **Network Security Group** (`vm-gmt-ubuntuNSG`) y verificar en la sección "Reglas de seguridad de entrada" que:
    > - La regla `default-allow-ssh` (para el puerto 22) ha sido **eliminada**.
    > - Una nueva regla (ej. `AllowSsh_2222` o la que creaste) ha sido **creada** y permite el acceso al puerto 2222.

### **Fase 5: Verificación Final del Blindaje**

**Ubicación:** Tu terminal local (WSL `gmt@MSI`).

1.  Intenta la nueva conexión segura.
    ```bash
    ssh -p 2222 gmt@<TU_IP_PÚBLICA>
    ```
    > **Resultado Esperado:** Deberías poder entrar directamente **sin que te pida contraseña**. ¡El blindaje ha sido un éxito!

### **Fase Final: Limpieza del Entorno**

**Ubicación:** Tu terminal local (WSL `gmt@MSI`).

1.  Cuando hayas terminado el laboratorio, ejecuta este script para eliminar todos los recursos de Azure y evitar costos.
    ```bash
    ./delete_resources.sh
    ```

---

## 📜 Código Completo de los Scripts

### `create_vm.sh`
```bash
#!/bin/bash
RESOURCE_GROUP_NAME="rg-gmt-vm-lab"
VM_NAME="vm-gmt-ubuntu"
LOCATION="eastus"
ADMIN_USERNAME="gmt"
ADMIN_PASSWORD="Password1234!"
UBUNTU_IMAGE="Ubuntu2404"
TAG_ENVIRONMENT="Development"
TAG_PROJECT="LinuxLab"
TAG_OWNER="gmt"
echo "=================================================="
echo "Iniciando el despliegue de la VM en Azure..."
echo "=================================================="
if ! az account show > /dev/null 2>&1; then
    echo "ERROR: No has iniciado sesión en Azure CLI."
    echo "Por favor, ejecuta 'az login' e inténtalo de nuevo."
    exit 1
fi
echo "Paso 1: Creando el Grupo de Recursos '$RESOURCE_GROUP_NAME' en '$LOCATION'..."
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION --tags environment="$TAG_ENVIRONMENT" project="$TAG_PROJECT" owner="$TAG_OWNER"
if [ $? -ne 0 ]; then
    echo "ERROR: Falló la creación del Grupo de Recursos. Abortando."
    exit 1
fi
echo "Grupo de Recursos creado exitosamente."
echo ""
echo "Paso 2: Creando la Máquina Virtual '$VM_NAME'..."
az vm create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VM_NAME \
    --image $UBUNTU_IMAGE \
    --size "Standard_B1s" \
    --storage-sku "Standard_LRS" \
    --admin-username $ADMIN_USERNAME \
    --admin-password $ADMIN_PASSWORD \
    --location $LOCATION \
    --tags environment="$TAG_ENVIRONMENT" project="$TAG_PROJECT" owner="$TAG_OWNER" \
    --nsg-rule SSH
if [ $? -ne 0 ]; then
    echo "ERROR: Falló la creación de la Máquina Virtual. Abortando."
    exit 1
fi
echo ""
echo "=================================================="
echo "¡Despliegue completado exitosamente!"
echo "=================================================="
echo "Para verificar los detalles de la VM, ejecuta: ./verify_vm.sh"
```

### `verify_vm.sh`
```bash
#!/bin/bash
RESOURCE_GROUP_NAME="rg-gmt-vm-lab"
VM_NAME="vm-gmt-ubuntu"
echo "=================================================="
echo "Verificando los detalles de la VM '$VM_NAME'..."
echo "=================================================="
if ! az account show > /dev/null 2>&1; then
    echo "ERROR: No has iniciado sesión en Azure CLI."
    exit 1
fi
VM_DETAILS=$(az vm show --resource-group $RESOURCE_GROUP_NAME --name $VM_NAME --show-details --query "{name:name, powerState:powerState, publicIp:publicIps, provisioningState:provisioningState, location:location}" -o json)
if [ -z "$VM_DETAILS" ]; then
    echo "ERROR: No se pudo encontrar la VM '$VM_NAME'."
    exit 1
fi
PUBLIC_IP=$(echo $VM_DETAILS | jq -r .publicIp)
POWER_STATE=$(echo $VM_DETAILS | jq -r .powerState)
echo "Detalles de la VM:"
echo "--------------------------------------------------"
echo "  Nombre de la VM:      $VM_NAME"
echo "  Estado de Energía:    $POWER_STATE"
echo "  IP Pública:           $PUBLIC_IP"
echo "--------------------------------------------------"
echo ""
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "null" ]; then
    echo "Puedes conectarte a la VM usando el siguiente comando:"
    echo "ssh gmt@$PUBLIC_IP"
fi
echo "=================================================="
```

### `delete_resources.sh`
```bash
#!/bin/bash
RESOURCE_GROUP_NAME="rg-gmt-vm-lab"
echo "=================================================="
echo "¡ADVERTENCIA! Estás a punto de eliminar el grupo de recursos '$RESOURCE_GROUP_NAME'."
echo "=================================================="
read -p "¿Estás seguro de que quieres continuar? (escribe 'si' para confirmar): " CONFIRMATION
if [ "$CONFIRMATION" != "si" ]; then
    echo "Operación cancelada."
    exit 0
fi
echo ""
echo "Iniciando la eliminación del grupo de recursos..."
az group delete --name $RESOURCE_GROUP_NAME --yes
if [ $? -ne 0 ]; then
    echo "ERROR: Ocurrió un error durante la eliminación."
else
    echo ""
    echo "=================================================="
    echo "¡Grupo de recursos eliminado exitosamente!"
    echo "=================================================="
fi
