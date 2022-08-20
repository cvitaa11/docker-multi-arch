FROM node:16.17.0-alpine
WORKDIR /usr/src/app

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]