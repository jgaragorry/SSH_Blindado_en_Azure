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
