Proyecto: SSH Blindado en Azure
Este repositorio contiene un conjunto de scripts y una guía detallada para desplegar una máquina virtual (VM) Ubuntu en Azure y aplicar un proceso de "hardening" (blindaje) a su servicio SSH. El objetivo es transformar una configuración por defecto vulnerable en una configuración segura y profesional, siguiendo las mejores prácticas de la industria.

Requisitos Previos
Para seguir esta guía, necesitarás tener instalado lo siguiente en tu máquina local (por ejemplo, en WSL):

Azure CLI: La interfaz de línea de comandos para interactuar con Azure.

Un cliente SSH: Estándar en la mayoría de los sistemas tipo Linux/macOS.

jq: Una herramienta de línea de comandos para procesar datos JSON (utilizada por el script verify_vm.sh). Puedes instalarla con sudo apt install jq.

Contenido del Repositorio
Este repositorio incluye tres scripts principales:

create_vm.sh: Despliega una VM Ubuntu 24.04 LTS en Azure con una configuración estándar y vulnerable (acceso por contraseña en el puerto 22).

verify_vm.sh: Verifica el estado y obtiene los detalles (como la IP pública) de la VM creada.

delete_resources.sh: Elimina de forma segura todo el grupo de recursos y la VM para evitar costos inesperados.

Guía de Ejecución Paso a Paso
Este es el proceso completo, desde la creación hasta el blindaje y la limpieza.

Paso 1: Desplegar la Máquina Virtual "Vulnerable"
Este paso crea nuestro entorno de laboratorio inicial.

En tu terminal local (WSL), asegúrate de haber iniciado sesión en Azure (az login).

Ejecuta el script de creación:

./create_vm.sh

Una vez que termine, ejecuta el script de verificación para obtener la IP pública y confirmar que la VM está en funcionamiento:

./verify_vm.sh

Anota la IP Pública que te proporciona, la usarás en los siguientes pasos.

Paso 2: Acceso Inicial y Preparación de la Llave
Ahora, demostraremos el acceso inseguro y prepararemos nuestra llave para el acceso seguro.

Desde tu terminal local, conéctate a la VM usando la contraseña (Password1234!):

ssh gmt@<TU_IP_PÚBLICA>

Esto demuestra que cualquiera que conozca la contraseña puede entrar.

En una nueva terminal local (deja la sesión SSH abierta), obtén tu llave pública. Esta es la "llave" que autorizaremos en el servidor.

cat ~/.ssh/id_rsa.pub

Copia toda la línea de salida (que empieza con ssh-rsa AAAA...).

Paso 3: Hardening Manual DENTRO de la VM
Vuelve a la terminal donde tienes la sesión SSH con la VM. Aquí realizaremos el blindaje.

Crear el directorio y archivo para llaves autorizadas:

mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys

Pegar tu llave pública: Abre el archivo con un editor de texto como nano:

nano ~/.ssh/authorized_keys

Pega la llave pública que copiaste en el paso anterior. Guarda y cierra (Ctrl+X, luego Y, luego Enter).

Corregir permisos (¡Paso crítico!):

chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

Modificar la configuración del servicio SSH:

sudo nano /etc/ssh/sshd_config

Dentro del archivo, busca y modifica estas tres líneas (elimina el # si lo tienen):

Cambia #Port 22 a Port 2222

Cambia PasswordAuthentication yes a PasswordAuthentication no

Cambia #PermitRootLogin prohibit-password a PermitRootLogin no

Validar la nueva configuración: Antes de reiniciar, asegúrate de que no hay errores de sintaxis.

sudo sshd -t

Si este comando no muestra nada, la configuración es correcta.

Configurar el firewall interno (UFW):

sudo ufw allow 2222/tcp

Reiniciar el servicio SSH: Este es el punto de no retorno. Tu conexión actual se cortará.

sudo systemctl restart ssh

Paso 4: Actualizar Reglas de Red en Azure
Vuelve a tu terminal local (WSL) para ajustar las reglas del firewall de la nube.

Abrir el nuevo puerto 2222:

az vm open-port --resource-group rg-gmt-vm-lab --name vm-gmt-ubuntu --port 2222 --priority 900

Cerrar el puerto inseguro 22 (muy recomendado):

az network nsg rule delete --resource-group rg-gmt-vm-lab --nsg-name vm-gmt-ubuntuNSG --name default-allow-ssh

Paso 5: Verificación Final
Desde tu terminal local, intenta la nueva conexión segura.

ssh -p 2222 gmt@<TU_IP_PÚBLICA>

Deberías poder entrar directamente sin que te pida contraseña. ¡El blindaje ha sido un éxito!

Paso Final: Limpieza de Recursos
Cuando hayas terminado tus pruebas, ejecuta este script desde tu terminal local para eliminar todos los recursos de Azure y evitar costos.

./delete_resources.sh

Código de los Scripts
create_vm.sh
#!/bin/bash

# ==============================================================================
# Script para Crear una VM Económica en Azure
# ==============================================================================
# Este script crea:
# 1. Un grupo de recursos.
# 2. Una máquina virtual Ubuntu 24.04 LTS con la configuración más económica.
#    - Tamaño: Standard_B1s (Burstable)
#    - Disco: Standard HDD (LRS)
#    - Red: Se abre el puerto 22 para SSH.
# ==============================================================================

# --- Variables de Configuración (Modificar si es necesario) ---
RESOURCE_GROUP_NAME="rg-gmt-vm-lab"
VM_NAME="vm-gmt-ubuntu"
LOCATION="eastus"
ADMIN_USERNAME="gmt"
ADMIN_PASSWORD="Password1234!"
UBUNTU_IMAGE="Ubuntu2404"

# --- Etiquetas para los Recursos (Buenas Prácticas / FinOps) ---
TAG_ENVIRONMENT="Development"
TAG_PROJECT="LinuxLab"
TAG_OWNER="gmt"

# --- Inicio del Script ---
echo "=================================================="
echo "Iniciando el despliegue de la VM en Azure..."
echo "=================================================="

# Verificar si el usuario ha iniciado sesión en Azure
if ! az account show > /dev/null 2>&1; then
    echo "ERROR: No has iniciado sesión en Azure CLI."
    echo "Por favor, ejecuta 'az login' e inténtalo de nuevo."
    exit 1
fi

echo "Paso 1: Creando el Grupo de Recursos '$RESOURCE_GROUP_NAME' en '$LOCATION'..."
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION --tags \
    environment="$TAG_ENVIRONMENT" \
    project="$TAG_PROJECT" \
    owner="$TAG_OWNER"

if [ $? -ne 0 ]; then
    echo "ERROR: Falló la creación del Grupo de Recursos. Abortando."
    exit 1
fi
echo "Grupo de Recursos creado exitosamente."
echo ""

echo "Paso 2: Creando la Máquina Virtual '$VM_NAME'..."
echo "         OS: $UBUNTU_IMAGE"
echo "         Tamaño: Standard_B1s (Económico)"
echo "         Usuario: $ADMIN_USERNAME"
echo "         Esta operación puede tardar varios minutos..."

# --- ¡¡¡ADVERTENCIA DE SEGURIDAD!!! ---
# NUNCA se debe colocar contraseñas en texto plano en un script en un entorno productivo.
# Para producción, se deben usar claves SSH o Azure Key Vault.
# Esto se hace así solo para cumplir con los requisitos específicos de esta tarea.
# ----------------------------------------
az vm create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $VM_NAME \
    --image $UBUNTU_IMAGE \
    --size "Standard_B1s" \
    --storage-sku "Standard_LRS" \
    --admin-username $ADMIN_USERNAME \
    --admin-password $ADMIN_PASSWORD \
    --location $LOCATION \
    --tags \
        environment="$TAG_ENVIRONMENT" \
        project="$TAG_PROJECT" \
        owner="$TAG_OWNER" \
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

verify_vm.sh
#!/bin/bash

# ==============================================================================
# Script para Verificar los Detalles de la VM en Azure
# ==============================================================================
# Este script muestra el estado de la VM y su dirección IP pública.
# ==============================================================================

# --- Variables de Configuración (Deben coincidir con create_vm.sh) ---
RESOURCE_GROUP_NAME="rg-gmt-vm-lab"
VM_NAME="vm-gmt-ubuntu"

# --- Inicio del Script ---
echo "=================================================="
echo "Verificando los detalles de la VM '$VM_NAME'..."
echo "=================================================="

# Verificar si el usuario ha iniciado sesión en Azure
if ! az account show > /dev/null 2>&1; then
    echo "ERROR: No has iniciado sesión en Azure CLI."
    echo "Por favor, ejecuta 'az login' e inténtalo de nuevo."
    exit 1
fi

# Obtener y mostrar los detalles de la VM
# Usamos --query para filtrar y mostrar solo la información relevante.
VM_DETAILS=$(az vm show --resource-group $RESOURCE_GROUP_NAME --name $VM_NAME --show-details --query "{name:name, powerState:powerState, publicIp:publicIps, provisioningState:provisioningState, location:location}" -o json)

if [ -z "$VM_DETAILS" ]; then
    echo "ERROR: No se pudo encontrar la VM '$VM_NAME' en el grupo de recursos '$RESOURCE_GROUP_NAME'."
    echo "Asegúrate de haber ejecutado ./create_vm.sh primero."
    exit 1
fi

PUBLIC_IP=$(echo $VM_DETAILS | jq -r .publicIp)
POWER_STATE=$(echo $VM_DETAILS | jq -r .powerState)
PROVISIONING_STATE=$(echo $VM_DETAILS | jq -r .provisioningState)
LOCATION=$(echo $VM_DETAILS | jq -r .location)


echo "Detalles de la VM:"
echo "--------------------------------------------------"
echo "  Nombre de la VM:      $VM_NAME"
echo "  Estado de Creación:   $PROVISIONING_STATE"
echo "  Estado de Energía:    $POWER_STATE"
echo "  Ubicación:            $LOCATION"
echo "  IP Pública:           $PUBLIC_IP"
echo "--------------------------------------------------"
echo ""

if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "null" ]; then
    echo "Puedes conectarte a la VM usando el siguiente comando:"
    echo "ssh gmt@$PUBLIC_IP"
else
    echo "La VM no tiene una IP pública asignada en este momento."
fi

echo "=================================================="

delete_resources.sh
#!/bin/bash

# ==============================================================================
# Script para Eliminar TODOS los recursos creados
# ==============================================================================
# Este script elimina el grupo de recursos completo.
# ¡¡¡PRECAUCIÓN!!! ESTA ACCIÓN ES IRREVERSIBLE.
# El script esperará a que el borrado se complete antes de finalizar.
# ==============================================================================

# --- Variables de Configuración (Deben coincidir con create_vm.sh) ---
RESOURCE_GROUP_NAME="rg-gmt-vm-lab"

# --- Inicio del Script ---
echo "=================================================="
echo "¡ADVERTENCIA! Estás a punto de eliminar el grupo de recursos"
echo "'$RESOURCE_GROUP_NAME' y TODOS los recursos que contiene."
echo "Esta acción no se puede deshacer."
echo "=================================================="
read -p "¿Estás seguro de que quieres continuar? (escribe 'si' para confirmar): " CONFIRMATION

if [ "$CONFIRMATION" != "si" ]; then
    echo "Operación cancelada por el usuario."
    exit 0
fi

echo ""
echo "Iniciando la eliminación del grupo de recursos '$RESOURCE_GROUP_NAME'..."
echo "Esta operación tardará varios minutos. El script no finalizará hasta que el proceso termine."

# El comando 'az group delete' por defecto espera a que la operación se complete.
# El flag --yes evita la pregunta de confirmación de Azure CLI.
az group delete --name $RESOURCE_GROUP_NAME --yes

if [ $? -ne 0 ]; then
    echo "ERROR: Ocurrió un error durante la eliminación."
else
    echo ""
    echo "=================================================="
    echo "¡Grupo de recursos eliminado exitosamente!"
    echo "=================================================="
fi
