FROM golang:1.22-alpine
WORKDIR /app
COPY . .
RUN if [ -f go.mod ] && [ "$(ls *.go 2>/dev/null | wc -l)" -gt "0" ]; then go build -o main .; fi
CMD ["sh", "-c", "if [ -f ./main ]; then ./main; else echo 'Service not yet implemented, sleeping...'; sleep infinity; fi"]
