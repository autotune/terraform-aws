#!/bin/bash
yum install docker -y 
service docker start
curl -L "https://github.com/docker/compose/releases/download/2.5.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo '
version: '3'

services:
  web:
    restart: always
    build: ./web
    expose:
      - "8000"
    links:
      - postgres:postgres
      - redis:redis
    volumes:
      - web-django:/usr/src/app
      - web-static:/usr/src/app/static
    env_file: .env
    environment:
      DEBUG: 'true'
    command: /usr/local/bin/gunicorn docker_django.wsgi:application -w 2 -b :8000

  nginx:
    restart: always
    build: ./nginx/
    ports:
      - "80:80"
    volumes:
      - web-static:/www/static
    links:
      - web:web

  postgres:
    restart: always
    image: postgres:latest
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data/

  redis:
    restart: always
    image: redis:latest
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data

volumes:
  web-django:
  web-static:
  pgdata:
  redisdata:' > ./docker-compose.yaml

docker-compose build 
docker-compose up -d 

printf '
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone  | sed -e "s/.$//")

PERFTEST="$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(curl http://169.254.169.254/latest/meta-data/instance-id)" --region $REGION |jq -r ".Tags[]|select(.Key == \\"PerfTest\\").Value")"

if [[ $PERFTEST == "CPU" ]];
then
    printf "$(stress --cpu 8)"

else
    pkill stress
fi

' > /root/failwhale.sh

crontab -l | { cat; echo "*/1 * * * * bash /root/failwhale.sh"; } | crontab -
