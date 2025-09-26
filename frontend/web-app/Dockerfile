FROM node:18-alpine as builder

# Build-time args for CRA env injection
ARG REACT_APP_API_URL
ARG REACT_APP_USE_MOCKS
ARG REACT_APP_GOOGLE_MAPS_API_KEY

# Expose as environment variables during build so CRA picks them up
ENV REACT_APP_API_URL=${REACT_APP_API_URL}
ENV REACT_APP_USE_MOCKS=${REACT_APP_USE_MOCKS}
ENV REACT_APP_GOOGLE_MAPS_API_KEY=${REACT_APP_GOOGLE_MAPS_API_KEY}

WORKDIR /app
COPY package*.json ./
# Use npm install instead of npm ci to allow updates after adding mock deps
RUN npm install --omit=dev

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]