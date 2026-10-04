FROM node:20-alpine

WORKDIR /frontend/

COPY . /frontend/

RUN npm install

ENV BACKEND_IP_ADDRESS=$BACKEND_IP_ADDRESS

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]