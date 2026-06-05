#!/bin/bash
set -e

export SEISCOMP_ROOT=/root/seiscomp
export PATH=/usr/bin:$SEISCOMP_ROOT/bin:/root/recovar-seiscomp/bin:$PATH
export LD_LIBRARY_PATH=$SEISCOMP_ROOT/lib
export PYTHONPATH=$SEISCOMP_ROOT/lib/python:/root/recovar:/root/recovar/seiscomp_integration

PY=/root/recovar-seiscomp/bin/python3
SEISCOMP_ROOT=/root/seiscomp

# Make the SeisComP env + demo shortcuts available in every shell (ssh / exec).
cat > /root/.bashrc << 'EOF'
export SEISCOMP_ROOT=/root/seiscomp
export PATH=/usr/bin:$SEISCOMP_ROOT/bin:/root/recovar-seiscomp/bin:$PATH
export LD_LIBRARY_PATH=$SEISCOMP_ROOT/lib
export PYTHONPATH=$SEISCOMP_ROOT/lib/python:/root/recovar:/root/recovar/seiscomp_integration
PY=/root/recovar-seiscomp/bin/python3
SDS=/root/seiscomp_test/sds
SC="seiscomp --asroot"
EOF

step() { echo ""; echo "========== $* =========="; }

step "0. Start MariaDB"
service mariadb start
sleep 3
mysql -e "CREATE DATABASE IF NOT EXISTS seiscomp;"
mysql -e "CREATE USER IF NOT EXISTS 'sysop'@'localhost' IDENTIFIED BY 'sysop';"
mysql -e "GRANT ALL ON seiscomp.* TO 'sysop'@'localhost'; FLUSH PRIVILEGES;"
mysql seiscomp < $SEISCOMP_ROOT/share/db/mysql.sql

step "1. SeisComP non-interactive config"
mkdir -p /root/.seiscomp /root/.seiscomp/log
cat > $SEISCOMP_ROOT/etc/global.cfg << 'EOF'
agencyID = TEST
datacenterID = TEST
recordstream = sdsarchive:///root/seiscomp_test/sds
EOF
cat > $SEISCOMP_ROOT/etc/kernel.cfg << 'EOF'
database.type = mysql
database.parameters = sysop:sysop@localhost/seiscomp
EOF

step "2. Install RECOVAR daemon"
cp /root/recovar/seiscomp_integration/recovar_pick_filter.py $SEISCOMP_ROOT/bin/recovar_pick_filter
sed -i "1s|.*|#!$PY|" $SEISCOMP_ROOT/bin/recovar_pick_filter
chmod +x $SEISCOMP_ROOT/bin/recovar_pick_filter
cp /root/recovar/seiscomp_integration/recovar_pick_filter.py.init $SEISCOMP_ROOT/etc/init/recovar_pick_filter.py

step "3. Verify imports"
$PY -c "
import seiscomp.client, seiscomp.datamodel, seiscomp.io
import tensorflow, recovar
from recovar.representation_learning_models import RepresentationLearningMultipleAutoencoder
from recovar.classifier_models import ClassifierMultipleAutoencoder
print('All imports OK — tensorflow', tensorflow.__version__)
"

step "4. Start SSH server"
service ssh start
echo "sshd listening on port 22 (root password: recovar)"

step "Setup complete — container is idle"
echo "The environment is configured. The pipeline was NOT run."
echo "Open a shell with:  docker exec -it recovar-seiscomp bash"
echo "                or: ssh -p 2222 root@localhost   (password: recovar)"
echo "Then follow seiscomp_integration/docker/DEMO.md to run the pick-filter demo."
echo ""
echo "Container will stay alive. Press Ctrl-C (or 'docker stop') to exit."

exec tail -f /dev/null
