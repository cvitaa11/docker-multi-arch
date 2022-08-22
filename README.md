# Building multi-architecture Docker images

In the last few years, the need for multi-architectural container images has grown significantly. Let's say you develop on your local Linux or Windows machine with an amd64 processor and want to publish your work to AWS machines with a Graviton2 processor, or simply want to share your work with colleagues who use Macbooks with an M1 chip, you need to ensure that your image works on both architectures. This process is significantly facilitated by the advent of the Docker Buildx tool.

But what is Buildx actually? According to the official documentation Docker Buildx is a CLI plugin that extends the docker command with the full support of the features provided by [Moby BuildKit](https://github.com/moby/buildkit) builder toolkit. It provides the same user experience as `docker build` with many new features like creating scoped builder instances and building against multiple nodes concurrently. Buildx also supports new features that are not yet available for regular `docker build` like building manifest lists, distributed caching, and exporting build results to OCI image tarballs.

In our demo, we will show how to setup buildx on a local machine and build a simple Node.js application. You can find the complete source code on [this](https://github.com/cvitaa11/docker-multi-arch) GitHub repository.

### Creating Node.js application

In the demo application, we created a web server using Node.js. Node.js provides extremely simple HTTP APIs so the example is very easy to understand even for non-javascript developers.

Basically, we define the port and then invoke the `createServer()` function on http module and create a response with a status code of 200 (OK), set a header and print a message on which architecture the program is running. We obtained the architecture of the CPU through the `arch` property of the built-in `process` variable. At the end we simply start a server listening for connections.

```
const http = require("http");

const port = 3000;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader("Content-Type", "text/plain");
  res.end(`Hello from ${process.arch} architecture!`);
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

If you want to test the app locally open the terminal in the working directory and run `node server.js` command.

In order to package the application in the form of a container, we have to write a Dockerfile. The first thing we need to do is define from what image we want to build from. Here we will use the version `16.17.0-alpine` of the official `node` image that is available on the Docker Hub. Right after the base image we will create a directory to hold the application code inside the image.

```
FROM node:16.17.0-alpine
WORKDIR /usr/src/app
```

To put the source code of our application into a Docker image, we'll use a simple copy command that will store the application code in the working directory.

```
COPY . .
```

Application is listening on port 3000 so we need to expose it and then finally start the server.

```
EXPOSE 3000
CMD ["node", "server.js"]
```

### Setup Buildx and create the image

The easiest way to setup `buildx` is by using [Docker Desktop](https://docs.docker.com/desktop/), because the tool is already included in the application. Docker Desktop is available for Windows, Linux and macOS so you can use it on any platform of your choice.

If you don't want to use Docker Desktop you can also download the latest binary from the [releases page](https://github.com/docker/buildx/releases/tag/v0.9.1) on GitHub, rename the binary to `docker-buildx` (`docker-buildx.exe` for Windows) and copy it to the destination matching your OS. For Linux and macOS that is `$HOME/.docker/cli-plugins`, for Windows that is `%USERPROFILE%\.docker\cli-plugins`.

In the code below you can see the setup for macOS:

```
ARCH=amd64 # change to 'arm64' if you have M1 chip
VERSION=v0.8.2
curl -LO https://github.com/docker/buildx/releases/download/${VERSION}/buildx-${VERSION}.darwin-${ARCH}
mkdir -p ~/.docker/cli-plugins
mv buildx-${VERSION}.darwin-${ARCH} ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
docker buildx version # verify installation
```

After installing `buildx` we need to create a new builder instace. Builder instances are isolated environments where builds can be invoked.

```
docker buildx create --name builder
```

When new builder instance is created we need to switch to it from the default one:

```
docker buildx use builder
```

Now let's see more informations about our builder instance. We will also pass `--bootstrap` option to ensure that the builder is running before inspecting it.

```
docker buildx inspect --bootstrap
```

Once we have made sure which platforms our builder instance supports, we can start creating the container image. Buildx is very similar to the `docker build` command and it takes the same arguments, of which we will primarily focus on `--platform` that sets target platform for build. In the code below we will sign in to Docker account, build the image and push it to Docker Hub.

```
docker login # prompts for username and password

docker buildx build \
 --platform linux/amd64,linux/arm64,linux/arm/v7 \
 -t cvitaa11/multi-arch:demo \
 --push \
 .
```

When the command completes we can go to Docker Hub and see [our image](https://hub.docker.com/r/cvitaa11/multi-arch/tags) with all the supported architectures.

It's time to test how the image works on different machines. First we will run it on Windows (Intel Core i5 CPU) with the command:

```
docker run -p 3000:3000 cvitaa11/multi-arch:demo
```

Let's navigate to the web browser to `localhost:3000` and chech the response.

Now let's switch to Macbook Pro with M1 chip and run the same command.

We see that our container image runs successfully on both processor architectures, which was our primary goal.
