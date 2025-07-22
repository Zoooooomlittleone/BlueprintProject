# Docker Worker Node Setup Script for Windows HP Laptop
# Run as Administrator in PowerShell

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   HP LAPTOP WORKER NODE SETUP                                " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host

# Check network configuration
Write-Host "CHECKING NETWORK CONFIGURATION..." -ForegroundColor Yellow
$currentIP = (Get-NetIPAddress | Where-Object {$_.IPAddress -eq "192.168.0.206"} | Select-Object -First 1).IPAddress
if ($currentIP -eq "192.168.0.206") {
    Write-Host "✓ IP Address correctly set to 192.168.0.206" -ForegroundColor Green
} else {
    Write-Host "✗ IP Address not set to 192.168.0.206" -ForegroundColor Red
    $response = Read-Host "  Would you like to set the IP address now? (y/n)"
    if ($response -eq "y") {
        $interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
        New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "192.168.0.206" -PrefixLength 24 -DefaultGateway "192.168.0.1"
        Write-Host "  IP Address has been set to 192.168.0.206" -ForegroundColor Green
    }
}

# Check hostname
Write-Host "`nCHECKING HOSTNAME..." -ForegroundColor Yellow
$currentName = hostname
if ($currentName -eq "hp-laptop") {
    Write-Host "✓ Hostname correctly set to hp-laptop" -ForegroundColor Green
} else {
    Write-Host "✗ Hostname not set to hp-laptop" -ForegroundColor Red
    $response = Read-Host "  Would you like to set the hostname now? (y/n)"
    if ($response -eq "y") {
        Rename-Computer -NewName "hp-laptop" -Force
        Write-Host "  Hostname set. Reboot required to apply changes." -ForegroundColor Yellow
        $rebootNeeded = $true
    }
}

# Check hosts file
Write-Host "`nCHECKING HOSTS FILE..." -ForegroundColor Yellow
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
$masterEntry = "192.168.0.200`tmaster"

# Check each entry for master node (may have extra spacing)
$hasMasterEntry = $false
foreach ($line in $hostsContent) {
    if ($line -match "192\.168\.0\.200\s+master") {
        $hasMasterEntry = $true
        break
    }
}

if (-not $hasMasterEntry) {
    Write-Host "✗ Master node entry not found in hosts file" -ForegroundColor Red
    $response = Read-Host "  Would you like to add it now? (y/n)"
    if ($response -eq "y") {
        Add-Content -Path $hostsPath -Value $masterEntry -Force
        Write-Host "  Master node entry added to hosts file" -ForegroundColor Green
    }
} else {
    Write-Host "✓ Master node entry found in hosts file" -ForegroundColor Green
}

# Check Docker installation
Write-Host "`nCHECKING DOCKER INSTALLATION..." -ForegroundColor Yellow
$dockerInstalled = Get-Service -Name docker -ErrorAction SilentlyContinue
if ($dockerInstalled) {
    Write-Host "✓ Docker is installed" -ForegroundColor Green
    
    if ($dockerInstalled.Status -eq "Running") {
        Write-Host "✓ Docker service is running" -ForegroundColor Green
    } else {
        Write-Host "✗ Docker service is not running" -ForegroundColor Red
        Write-Host "  Starting Docker service..." -ForegroundColor Yellow
        Start-Service docker
        Write-Host "  Docker service started" -ForegroundColor Green
    }
    
    # Check swarm status
    try {
        $swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}' 2>$null
        if ($swarmStatus -eq "active") {
            Write-Host "✓ Node is already part of Docker swarm" -ForegroundColor Green
            Write-Host "  This node appears as 'hp-docker-desktop' in the swarm node list" -ForegroundColor Cyan
        } else {
            Write-Host "✗ Node is not part of Docker swarm" -ForegroundColor Red
            
            # Try to ping master
            $pingTest = Test-Connection -ComputerName "192.168.0.200" -Count 1 -Quiet
            if ($pingTest) {
                Write-Host "`nCONNECTING TO MASTER NODE..." -ForegroundColor Yellow
                
                $useStoredToken = Read-Host "Do you want to use the stored token? (y/n)"
                
                if ($useStoredToken -eq "y") {
                    # Stored token from configuration (updated March 30, 2025)
                    $storedToken = "SWMTKN-1-49uqsg7eoqeb3o02gc70so5u85phyqgd1c9iu4og703j5u6mwh-1z2s7z40c17eba5fv6e7x95do"
                    Write-Host "`nJoining the Docker swarm with stored token..." -ForegroundColor Yellow
                    docker swarm join --token $storedToken 192.168.0.200:2377
                } else {
                    # Connect to master to get join token
                    Write-Host "`nTo add this node to the swarm, you need the join token from the master." -ForegroundColor Yellow
                    Write-Host "Run this command on the master server (Pop OS):" -ForegroundColor Cyan
                    Write-Host "docker swarm join-token worker -q" -ForegroundColor White
                    $token = Read-Host "`nEnter the token from the master"
                    
                    if ($token) {
                        # Join the swarm
                        Write-Host "`nJoining the Docker swarm..." -ForegroundColor Yellow
                        docker swarm join --token $token 192.168.0.200:2377
                    }
                }
            } else {
                Write-Host "✗ Cannot reach master node (192.168.0.200)" -ForegroundColor Red
                Write-Host "  Please check network connectivity before joining swarm" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "✗ Error checking swarm status: $_" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Docker is not installed" -ForegroundColor Red
    Write-Host "  Please install Docker Desktop for Windows from:" -ForegroundColor Yellow
    Write-Host "  https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
    Write-Host "  After installation completes, restart your computer" -ForegroundColor Yellow
    Write-Host "  Then run this script again to complete the setup" -ForegroundColor Yellow
}

# Final status
Write-Host "`n===============================================================" -ForegroundColor Cyan
Write-Host "   WORKER NODE SETUP - SUMMARY                               " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

if ($rebootNeeded) {
    Write-Host "`nSome changes require a system restart to take effect." -ForegroundColor Yellow
    Write-Host "Please restart this computer when convenient." -ForegroundColor Yellow
}

Write-Host "`nTROUBLESHOOTING TIPS:" -ForegroundColor Yellow
Write-Host "• Ensure Docker Desktop is running" -ForegroundColor White
Write-Host "• Check firewall settings if you can't join the swarm" -ForegroundColor White
Write-Host "• Verify you can ping the master node (192.168.0.200)" -ForegroundColor White
Write-Host "• Run Docker commands as Administrator" -ForegroundColor White
Write-Host "• If issues persist, ensure Windows Defender Firewall allows Docker" -ForegroundColor White
Write-Host "• Note: This HP laptop will likely appear as 'docker-desktop' in the swarm node list" -ForegroundColor Cyan
Write-Host "• To verify connection, run: docker node ls" -ForegroundColor White

Write-Host "`n===============================================================" -ForegroundColor Cyan
