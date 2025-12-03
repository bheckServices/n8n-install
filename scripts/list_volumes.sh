#!/bin/bash

echo "=== All Docker Volumes ==="
echo ""
echo "Volumes with 'localai' prefix (current project):"
docker volume ls --filter "name=localai" --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
echo ""
echo "=== End of Volume List ==="
