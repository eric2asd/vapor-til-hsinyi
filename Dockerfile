# 1
FROM swift:4.2

# 2
WORKDIR /package
# 3
COPY . ./
# 4
RUN swift package resolve
RUN swift package clean
# 5
CMD ["swift", "test"]