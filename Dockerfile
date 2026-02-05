FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["ModernizeInfraApp/ModernizeInfraApp.csproj", "ModernizeInfraApp/"]
RUN dotnet restore "ModernizeInfraApp/ModernizeInfraApp.csproj"
COPY . .
WORKDIR "/src/ModernizeInfraApp"
RUN dotnet build "ModernizeInfraApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "ModernizeInfraApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS final
WORKDIR /app
EXPOSE 8080
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ModernizeInfraApp.dll"]
