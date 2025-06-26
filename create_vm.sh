---
---

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Archivo 2: create_vm.sh
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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