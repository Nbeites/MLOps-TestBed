## Quick WSL setup for development

This guide shows how to quickly prepare a development environment in **WSL (Windows Subsystem for Linux)** to work with Python projects (including this repository).

---

### 1️⃣ Install WSL

In **PowerShell as Administrator**:

```powershell
wsl --install
```

By default, this installs the **Ubuntu** distro.

Restart the PC when the installation finishes.

---

### 2️⃣ Open Linux and update it

After the reboot, open the **Ubuntu** app (it will ask you to create a user).

Then run:

```bash
sudo apt update
sudo apt upgrade
```

---

### 3️⃣ Install base tools

In the Ubuntu terminal:

```bash
sudo apt install -y git python3 python3-pip python3-venv build-essential
```

With this you get a functional Python environment for development.

---

### 4️⃣ Create a projects folder

Inside Ubuntu:

```bash
mkdir -p ~/projects
cd ~/projects
```

This folder appears in Windows at:

```text
\\wsl$\Ubuntu\home\TEU_USER\projects
```

You can drag files here using Explorer if needed.

Suggestion: clone this repository inside `~/projects`:

```bash
cd ~/projects
git clone https://github.com/SEU_USER/MLOps-TestBed.git
cd MLOps-TestBed
```

---

### 5️⃣ Connect the editor (VS Code + Remote WSL)

In Windows, install:

- **Visual Studio Code**
- Extensão **Remote - WSL**

Then, in the Ubuntu terminal (inside the project folder):

```bash
code .
```

VS Code opens connected directly to the Linux (WSL) environment, which avoids performance and path issues.

---

### 6️⃣ Create a Python environment per project

Inside a project (for example, `~/projects/MLOps-TestBed`):

```bash
python3 -m venv venv
source venv/bin/activate
```

Install dependencies:

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

Whenever you come back to the project, activate the environment:

```bash
cd ~/projects/MLOps-TestBed
source venv/bin/activate
```

---

### 7️⃣ (Optional) Local AI with Ollama

If you want to run AI models locally on Windows:

1. Install **Ollama** (on Windows) from the official website.
2. Then, in PowerShell or CMD:

```powershell
ollama run llama3
```

This downloads and runs the **Llama 3** model locally.

---

## 💾 WSL backup / snapshot

WSL lets you export the entire distro to a file, which is great for backup or migration.

1. Check the distro name:

```powershell
wsl -l -v
```

2. Create a backup (in PowerShell or CMD):

```powershell
wsl --export Ubuntu backup_wsl.tar
```

This creates a full snapshot of Ubuntu.

### Restore snapshot

```powershell
wsl --import UbuntuRestored C:\WSL\Ubuntu backup_wsl.tar
```

You get an identical copy of the original distro.

---

### ⭐ Trick commonly used by devs

Many people automate a **weekly snapshot**:

- Create a `.ps1` script with the `wsl --export ...` command
- Schedule it in the **Windows Task Scheduler**

This way you get automatic backups of the Linux environment.

---

## 🧠 Important performance tip

Keep your projects **inside Linux**, for example in:

```text
~/projects
```

and **not** in `/mnt/c`.

Reason: tools like `pip`, `git`, and builds in general are **much faster** when files are in WSL’s native filesystem.

---

## ✅ Ultra-short summary

- `wsl --install`
- Install Python + git (`sudo apt install git python3 python3-pip python3-venv build-essential`)
- Create `~/projects` and keep repos there
- Use **VS Code + Remote WSL** (`code .`)
- Create a `venv` per project (`python3 -m venv venv && source venv/bin/activate`)
- Backup with `wsl --export Ubuntu backup_wsl.tar`

