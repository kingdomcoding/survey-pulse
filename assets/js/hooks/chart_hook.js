import Chart from "chart.js/auto"

const TrendChart = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  renderChart() {
    const data = JSON.parse(this.el.dataset.trend)

    if (this.chart) {
      this.chart.destroy()
    }

    if (!data || data.length === 0) return

    const labels = data.map(d => d.wave_label)
    const scores = data.map(d => d.avg_score)
    const significant = data.map(d => d.significant)

    const ctx = document.createElement("canvas")
    this.el.innerHTML = ""
    this.el.appendChild(ctx)

    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [{
          label: "Avg Score",
          data: scores,
          borderColor: "#4f46e5",
          backgroundColor: "rgba(79, 70, 229, 0.08)",
          fill: true,
          tension: 0.3,
          pointRadius: scores.map((_, i) => significant[i] ? 8 : 4),
          pointBackgroundColor: scores.map((_, i) => {
            if (!significant[i]) return "#4f46e5"
            const delta = data[i].delta
            return delta > 0 ? "#059669" : "#dc2626"
          }),
          pointBorderColor: "#fff",
          pointBorderWidth: 2,
          borderWidth: 2.5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#1f2937",
            titleFont: { size: 13 },
            bodyFont: { size: 12 },
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              afterLabel(ctx) {
                const point = data[ctx.dataIndex]
                const delta = point.delta
                const sig = point.significant
                let str = `Change: ${delta > 0 ? "+" : ""}${delta.toFixed(2)}`
                if (sig) str += " ★ Significant"
                str += `\nResponses: ${point.response_count.toLocaleString()}`
                return str
              }
            }
          }
        },
        scales: {
          y: {
            grid: { color: "rgba(0,0,0,0.04)" },
            ticks: { font: { size: 12 }, color: "#6b7280" }
          },
          x: {
            grid: { display: false },
            ticks: { font: { size: 12 }, color: "#6b7280" }
          }
        }
      }
    })
  },

  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

export default TrendChart
