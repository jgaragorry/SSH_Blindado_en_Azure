# ==========================================================
#      Paquete de Archivos para Repositorio "ssh_blindado"
# ==========================================================
#
# Instrucciones:
# 1. Copia el contenido de cada sección de abajo.
# 2. Pega el contenido en un nuevo archivo de texto en tu máquina local.
# 3. Guarda cada archivo con el nombre indicado (ej. README.md, create_vm.sh, etc.).
# 4. Una vez guardados todos los archivos en una carpeta, puedes crear un .zip con ellos.
#
# ==========================================================

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Archivo 1: README.md
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Proyecto: SSH Blindado en Azure

Este repositorio contiene un conjunto de scripts y una guía detallada para desplegar una máquina virtual (VM) Ubuntu en Azure y aplicar un proceso de "hardening" (blindaje) a su servicio SSH. El objetivo es transformar una configuración por defecto vulnerable en una configuración segura y profesional, siguiendo las mejores prácticas de la industria.

---

## Requisitos Previos

Para seguir esta guía, necesitarás tener instalado lo siguiente en tu máquina local (por ejemplo, en WSL):

1.  **Azure CLI:** La interfaz de línea de comandos para interactuar con Azure.
2.  **Un cliente SSH:** Estándar en la mayoría de los sistemas tipo Linux/macOS.
3.  **`jq`:** Una herramienta de línea de comandos para procesar datos JSON (utilizada por el script `verify_vm.sh`). Puedes instalarla con `sudo apt install jq`.

---

## Contenido del Repositorio

Este repositorio incluye tres scripts principales:

1.  **`create_vm.sh`**: Despliega una VM Ubuntu 24.04 LTS en Azure con una configuración estándar y vulnerable (acceso por contraseña en el puerto 22).
2.  **`verify_vm.sh`**: Verifica el estado y obtiene los detalles (como la IP pública) de la VM creada.
3.  **`delete_resources.sh`**: Elimina de forma segura todo el grupo de recursos y la VM para evitar costos inesperados.

---

## Guía de Ejecución Paso a Paso

Este es el proceso completo, desde la creación hasta el blindaje y la limpieza.

### **Paso 1: Desplegar la Máquina Virtual "Vulnerable"**

Este paso crea nuestro entorno de laboratorio inicial.

1.  En tu terminal local (WSL), asegúrate de haber iniciado sesión en Azure (`az login`).
2.  Ejecuta el script de creación:
    ```bash
    ./create_vm.sh
    ```
3.  Una vez que termine, ejecuta el script de verificación para obtener la IP pública y confirmar que la VM está en funcionamiento:
    ```bash
    ./verify_vm.sh
    ```
    *Anota la **IP Pública** que te proporciona, la usarás en los siguientes pasos.*

### **Paso 2: Acceso Inicial y Preparación de la Llave**

Ahora, demostraremos el acceso inseguro y prepararemos nuestra llave para el acceso seguro.

1.  Desde tu terminal local, conéctate a la VM usando la contraseña (`Password1234!`):
    ```bash
    ssh gmt@<TU_IP_PÚBLICA>
    ```
    *Esto demuestra que cualquiera que conozca la contraseña puede entrar.*

2.  En una **nueva terminal local** (deja la sesión SSH abierta), obtén tu llave pública. Esta es la "llave" que autorizaremos en el servidor.
    ```bash
    cat ~/.ssh/id_rsa.pub
    ```
3.  **Copia toda la línea de salida** (que empieza con `ssh-rsa AAAA...`).

### **Paso 3: Hardening Manual DENTRO de la VM**

Vuelve a la terminal donde tienes la sesión SSH con la VM. Aquí realizaremos el blindaje.

1.  **Crear el directorio y archivo para llaves autorizadas:**
    ```bash
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    ```
2.  **Pegar tu llave pública:** Abre el archivo con un editor de texto como `nano`:
    ```bash
    nano ~/.ssh/authorized_keys
    ```
    Pega la llave pública que copiaste en el paso anterior. Guarda y cierra (`Ctrl+X`, luego `Y`, luego `Enter`).

3.  **Corregir permisos (¡Paso crítico!):**
    ```bash
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    ```

4.  **Modificar la configuración del servicio SSH:**
    ```bash
    sudo nano /etc/ssh/sshd_config
    ```
    Dentro del archivo, busca y modifica estas tres líneas (elimina el `#` si lo tienen):
    * Cambia `#Port 22` a `Port 2222`
    * Cambia `PasswordAuthentication yes` a `PasswordAuthentication no`
    * Cambia `#PermitRootLogin prohibit-password` a `PermitRootLogin no`

5.  **Validar la nueva configuración:** Antes de reiniciar, asegúrate de que no hay errores de sintaxis.
    ```bash
    sudo sshd -t
    ```
    *Si este comando no muestra nada, la configuración es correcta.*

6.  **Configurar el firewall interno (UFW):**
    ```bash
    sudo ufw allow 2222/tcp
    ```

7.  **Reiniciar el servicio SSH:** Este es el punto de no retorno. Tu conexión actual se cortará.
    ```bash
    sudo systemctl restart ssh
    ```

### **Paso 4: Actualizar Reglas de Red en Azure**

Vuelve a tu terminal local (WSL) para ajustar las reglas del firewall de la nube.

1.  **Abrir el nuevo puerto 2222:**
    ```bash
    az vm open-port --resource-group rg-gmt-vm-lab --name vm-gmt-ubuntu --port 2222 --priority 900
    ```
2.  **Cerrar el puerto inseguro 22 (muy recomendado):**
    ```bash
    az network nsg rule delete --resource-group rg-gmt-vm-lab --nsg-name vm-gmt-ubuntuNSG --name default-allow-ssh
    ```

### **Paso 5: Verificación Final**

Desde tu terminal local, intenta la nueva conexión segura.
```bash
ssh -p 2222 gmt@<TU_IP_PÚBLICA>
```
*Deberías poder entrar directamente sin que te pida contraseña.* ¡El blindaje ha sido un éxito!

### **Paso Final: Limpieza de Recursos**

Cuando hayas terminado tus pruebas, ejecuta este script desde tu terminal local para eliminar todos los recursos de Azure y evitar costos.
```bash
./delete_resources.sh
```