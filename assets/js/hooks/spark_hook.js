import Chart from "chart.js/auto"

const SparkLine = {
  mounted() {
    this.chart = null
    this.render()
  },

  updated() {
    this.render()
  },

  render() {
    const scores = JSON.parse(this.el.dataset.scores)
    const color = this.el.dataset.color || "#818cf8"
    if (this.chart) this.chart.destroy()
    if (!scores || scores.length === 0) return

    const canvas = document.createElement("canvas")
    this.el.innerHTML = ""
    this.el.appendChild(canvas)

    this.chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: scores.map((_, i) => i),
        datasets: [{
          data: scores,
          borderColor: color,
          backgroundColor: color + "18",
          borderWidth: 1.5,
          pointRadius: 0,
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false }, tooltip: { enabled: false } },
        scales: {
          x: { display: false },
          y: { display: false }
        }
      }
    })
  },

  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

export default SparkLine
