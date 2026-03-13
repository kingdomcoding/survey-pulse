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
    const questionType = this.el.dataset.questionType || "likert"
    const scaleMin = parseFloat(this.el.dataset.scaleMin) || 0
    const scaleMax = parseFloat(this.el.dataset.scaleMax) || 10

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
          label: questionType === "nps" ? "NPS Score" : "Avg Score",
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
              label(ctx) {
                return `Score: ${data[ctx.dataIndex].avg_score}`
              },
              afterLabel(ctx) {
                const point = data[ctx.dataIndex]
                const lines = []
                if (point.wave_number > 1) {
                  const delta = point.delta
                  const dir = delta > 0 ? "Up" : delta < 0 ? "Down" : "No change"
                  if (dir === "No change") {
                    lines.push("No change from previous round")
                  } else {
                    lines.push(`${dir} ${Math.abs(delta).toFixed(2)} pts from previous round`)
                  }
                  if (point.significant) lines.push("Statistically significant")
                } else {
                  lines.push("First round (baseline)")
                }
                lines.push(`${point.response_count.toLocaleString()} responses`)
                return lines
              }
            }
          }
        },
        scales: {
          y: {
            min: scaleMin,
            max: scaleMax,
            grid: { color: "rgba(0,0,0,0.04)" },
            ticks: { font: { size: 12 }, color: "#6b7280" },
            title: { display: true, text: questionType === "nps" ? "NPS Score" : "Score", font: { size: 12 }, color: "#9ca3af" }
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
