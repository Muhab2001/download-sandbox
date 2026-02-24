# Variables
IMAGE_NAME = hardened-sandbox
# Directory on Mac to store virus definitions
DB_VOL = clamav_db
# Directory on Mac to receive safe files
SAFE_DIR = $(shell pwd)/safe_files
# Directory on Mac containing Yara rules
RULES_DIR = $(shell pwd)/yara_rules

.PHONY: build update-db scan clean shell

# 1. Build the image
build:
	@docker build -t $(IMAGE_NAME) .
	@docker volume create $(DB_VOL)
	@mkdir -p $(SAFE_DIR)
	@mkdir -p $(RULES_DIR)

# 2. Update Virus Definitions (Run this periodically)
update-db:
	@echo "--- 🔄 Updating ClamAV definitions ---"
	@docker run --rm \
		-v $(DB_VOL):/var/lib/clamav \
		--entrypoint /usr/bin/freshclam \
		$(IMAGE_NAME) \
		--stdout
	@echo ""
	@echo "--- 📜 Updating Yara rules ---"
	@docker run --rm \
		-v $(RULES_DIR):/rules \
		--entrypoint /bin/bash \
		$(IMAGE_NAME) \
		-c "set -e; \
		    echo '[*] Downloading EICAR (Test)...'; \
		    wget -qN https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Eicar.yar -P /rules; \
		    echo '[*] Downloading Crypto Miner Rules (Common in sketchy software)...'; \
		    wget -qN https://raw.githubusercontent.com/Yara-Rules/rules/master/crypto/crypto_signatures.yar -P /rules; \
		    echo '[*] Downloading Packer Rules (Detects hidden malware)...'; \
		    wget -qN https://raw.githubusercontent.com/Yara-Rules/rules/master/packers/peid.yar -P /rules; \
		    echo '[*] Downloading Capabilities Rules (Detects suspicious code behavior)...'; \
		    wget -qN https://raw.githubusercontent.com/Yara-Rules/rules/master/capabilities/capabilities.yar -P /rules; \
		    echo '✅ Yara rules update complete.'"
# 3. Run the scan
# Usage: make scan url=https://example.com/file.zip
scan:
	@if [ -z "$(url)" ]; then \
		echo "Error: Usage: make scan url=https://example.com/file.zip"; \
		exit 1; \
	fi
	@docker run --rm \
		--cap-drop=ALL \
		--security-opt=no-new-privileges:true \
		--read-only \
		--tmpfs /sandbox:uid=10001,gid=10001,mode=1777 \
		--tmpfs /tmp:uid=10001,gid=10001 \
		--mount source=$(DB_VOL),target=/var/lib/clamav,readonly \
		-v $(SAFE_DIR):/output \
		-v $(RULES_DIR):/rules:ro \
		--memory="1g" \
		--cpus="1.0" \
		--network=bridge \
		$(IMAGE_NAME) "$(url)"

# 4. Debug shell (if you need to inspect manually)
shell:
	@docker run --rm -it \
		--cap-drop=ALL \
		--read-only \
		--tmpfs /sandbox:uid=10001,gid=10001 \
		--tmpfs /tmp:uid=10001,gid=10001 \
		--mount source=$(DB_VOL),target=/var/lib/clamav,readonly \
		--entrypoint /bin/bash \
		$(IMAGE_NAME)

clean:
	@docker rmi $(IMAGE_NAME)
	@docker volume rm $(DB_VOL)
