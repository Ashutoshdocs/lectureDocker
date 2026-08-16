function dockerDashboard() {

  const data = {
    buildStage: "Node.js",
    productionStage: "Nginx",
    containerPort: 80,
    optimized: true
  };

  console.log("Docker Dashboard");
  console.log(data);

}

dockerDashboard();