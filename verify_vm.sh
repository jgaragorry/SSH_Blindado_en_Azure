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