FROM node:16-buster

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy the rest of the application code
COPY . .

# Build the Backstage app
RUN yarn build

# Expose the port
EXPOSE 7007

# Start the Backstage app
CMD ["yarn", "start"]