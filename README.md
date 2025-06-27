Este repositorio contiene una guía detallada y un conjunto de scripts para demostrar el proceso manual de "hardening" (blindaje) de un servicio SSH en una máquina virtual Ubuntu desplegada en Azure.El objetivo es transformar una configuración por defecto, que permite el acceso por contraseña a través del puerto 22, en una configuración segura y profesional que exige el uso de llaves criptográficas a través de un puerto no estándar.📋 Tabla de Contenido🎯 Objetivo del Laboratorio🛠️ Requisitos Previos📂 Contenido del Repositorio🚀 Guía de Ejecución Paso a PasoFase 1: Despliegue del EntornoFase 2: Preparación y Acceso InicialFase 3: Hardening Manual DENTRO de la VMFase 4: Actualización de Reglas de Red en AzureFase 5: Verificación Final del BlindajeFase Final: Limpieza de Recursos📜 Código Completo de los Scripts🎯 Objetivo del LaboratorioEste laboratorio está diseñado para que los profesionales de TI y ciberseguridad puedan:Comprender las debilidades de una configuración SSH por defecto.Implementar la autenticación basada en llaves, el método más seguro.Modificar el puerto de escucha de SSH para reducir la exposición a ataques automatizados.Configurar correctamente tanto el firewall del sistema operativo (UFW) como las reglas de red de Azure (NSG).🛠️ Requisitos PreviosAntes de comenzar, asegúrate de tener lo siguiente en tu máquina local (ej. WSL):HerramientaComando de Verificación / InstalaciónPropósitoAzure CLIaz versionPara interactuar con tu suscripción de Azure.Cliente SSHssh -VPara conectarse a la máquina virtual.jqsudo apt install jqPara procesar la salida JSON de Azure CLI.Nota Importante: Debes haber iniciado sesión en Azure CLI antes de ejecutar los scripts. Usa el comando az login.📂 Contenido del RepositorioScriptDescripción📜 create_vm.shDespliega la VM Ubuntu 24.04 vulnerable en Azure.🔍 verify_vm.shVerifica el estado y obtiene los detalles de la VM.🧹 delete_resources.shElimina todos los recursos de Azure y espera a que el proceso finalice.🚀 Guía de Ejecución Paso a PasoFase 1: Despliegue del Entorno de LaboratorioUbicación: Tu terminal local (WSL gmt@MSI).Crear la VM: Ejecuta el script para desplegar el servidor Ubuntu en Azure../create_vm.sh
Verificar y Obtener IP: Una vez que termine, ejecuta el script de verificación para obtener la dirección IP pública. Anota esta IP, la necesitarás para todo lo demás../verify_vm.sh
Fase 2: Preparación y Acceso InicialObtener tu Llave Pública (En tu WSL Local): Necesitamos tu llave pública para autorizarla en el servidor. Ejecuta este comando para mostrarla en pantalla.cat ~/.ssh/id_rsa.pub
Copia toda la línea de salida (que empieza con ssh-rsa AAAA...). Mantenla en tu portapapeles.Conectarse a la VM Vulnerable (Desde tu WSL Local): Usa la IP del paso anterior para conectarte por primera (y última) vez con contraseña.ssh gmt@<TU_IP_PÚBLICA>
Usa la contraseña Password1234!.Fase 3: Hardening Manual DENTRO de la VMUbicación: DENTRO de la VM de Azure (en la sesión SSH que acabas de abrir).Instalar tu Llave Pública:# Crear el directorio y el archivo de llaves autorizadas
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys

# Abrir el archivo con el editor nano
nano ~/.ssh/authorized_keys 

# Dentro de nano, pega la llave pública que copiaste en la Fase 2.
# Guarda y cierra (Ctrl+X, luego Y, luego Enter).
Corregir Permisos (¡Paso Crítico!): SSH no aceptará la llave si los permisos son incorrectos.chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
Modificar la Configuración del Servicio SSH:sudo nano /etc/ssh/sshd_config
Dentro del archivo, busca y modifica estas tres líneas (elimina el # si lo tienen):Cambia #Port 22 a Port 2222Cambia PasswordAuthentication yes a PasswordAuthentication noCambia #PermitRootLogin prohibit-password a PermitRootLogin noValidar la Configuración de SSH: Antes de reiniciar, asegúrate de que no hay errores de sintaxis.sudo sshd -t
Si este comando no muestra nada, la configuración es correcta.Configurar el Firewall Interno (UFW):sudo ufw allow 2222/tcp
Reiniciar el Servicio SSH: Este es el punto de no retorno. Tu conexión actual se cortará.sudo systemctl restart ssh
¡Es normal y esperado que tu sesión SSH se congele o se cierre en este momento!Fase 4: Actualizar Reglas de Red en AzureUbicación: Tu terminal local (WSL gmt@MSI).Abrir el nuevo puerto 2222 en el firewall de Azure:az vm open-port --resource-group rg-gmt-vm-lab --name vm-gmt-ubuntu --port 2222 --priority 900
Cerrar el puerto inseguro 22 (muy recomendado):az network nsg rule delete --resource-group rg-gmt-vm-lab --nsg-name vm-gmt-ubuntuNSG --name default-allow-ssh
Fase 5: Verificación Final del BlindajeUbicación: Tu terminal local (WSL gmt@MSI).Intenta la nueva conexión segura.ssh -p 2222 gmt@<TU_IP_PÚBLICA>
Resultado Esperado: Deberías poder entrar directamente sin que te pida contraseña. ¡El blindaje ha sido un éxito!Fase Final: Limpieza del EntornoUbicación: Tu terminal local (WSL gmt@MSI).Cuando hayas terminado el laboratorio, ejecuta este script para eliminar todos los recursos de Azure y evitar costos../delete_resources.sh
📜 Código Completo de los Scriptscreate_vm.sh#!/bin/bash
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
verify_vm.sh#!/bin/bash
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
delete_resources.sh#!/bin/bash
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
