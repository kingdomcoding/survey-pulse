import Chart from "chart.js/auto"
import ChartDataLabels from "chartjs-plugin-datalabels"

const formatLabel = (s) => {
  const map = {
    "non_binary": "Non-Binary",
    "prefer_not_to_say": "Prefer Not to Say",
    "north_america": "North America",
    "asia_pacific": "Asia Pacific",
    "latin_america": "Latin America",
    "18-24": "18–24", "25-34": "25–34", "35-44": "35–44",
    "45-54": "45–54", "55-64": "55–64", "65+": "65+"
  }
  return map[s] || s.charAt(0).toUpperCase() + s.slice(1)
}

const BreakdownChart = {
  mounted() {
    this.chart = null
    this.render()
  },
  updated() { this.render() },
  render() {
    const data = JSON.parse(this.el.dataset.breakdown)
    if (this.chart) this.chart.destroy()
    if (!data || data.length === 0) return

    const maxScore = Math.max(...data.map(d => d.avg_score))
    const canvas = document.createElement("canvas")
    this.el.innerHTML = ""
    this.el.appendChild(canvas)

    this.chart = new Chart(canvas, {
      type: "bar",
      plugins: [ChartDataLabels],
      data: {
        labels: data.map(d => formatLabel(d.segment)),
        datasets: [{
          data: data.map(d => d.avg_score),
          backgroundColor: data.map(d =>
            d.avg_score === maxScore ? "rgba(79, 70, 229, 0.15)" : "rgba(107, 114, 128, 0.08)"
          ),
          borderColor: data.map(d =>
            d.avg_score === maxScore ? "#4f46e5" : "#d1d5db"
          ),
          borderWidth: 1.5,
          borderRadius: 6,
          barPercentage: 0.7
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        layout: { padding: { right: 40 } },
        plugins: {
          legend: { display: false },
          datalabels: {
            anchor: "end",
            align: "end",
            offset: 4,
            font: { size: 12, weight: "600" },
            color: (ctx) =>
              data[ctx.dataIndex].avg_score === maxScore ? "#4f46e5" : "#6b7280",
            formatter: (val) => val.toFixed(1)
          },
          tooltip: {
            backgroundColor: "#1f2937",
            titleFont: { size: 13 },
            bodyFont: { size: 12 },
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              afterLabel(ctx) {
                const point = data[ctx.dataIndex]
                return [
                  `${point.response_count.toLocaleString()} responses`,
                  `Top-2 Box: ${point.top2_box}%`
                ]
              }
            }
          }
        },
        scales: {
          x: {
            grid: { color: "rgba(0,0,0,0.03)" },
            ticks: { display: false }
          },
          y: {
            grid: { display: false },
            ticks: { font: { size: 13 }, color: "#374151" }
          }
        }
      }
    })
  },
  destroyed() { if (this.chart) this.chart.destroy() }
}

export default BreakdownChart
