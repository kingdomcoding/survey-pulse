import Chart from "chart.js/auto"

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

    const canvas = document.createElement("canvas")
    this.el.innerHTML = ""
    this.el.appendChild(canvas)

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: data.map(d => formatLabel(d.segment)),
        datasets: [{
          label: "Avg Score",
          data: data.map(d => d.avg_score),
          backgroundColor: "#818cf833",
          borderColor: "#6366f1",
          borderWidth: 1.5,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
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
                return [`${point.response_count.toLocaleString()} responses`, `Top-2 Box: ${point.top2_box}%`]
              }
            }
          }
        },
        scales: {
          x: { grid: { color: "rgba(0,0,0,0.04)" } },
          y: { grid: { display: false } }
        }
      }
    })
  },
  destroyed() { if (this.chart) this.chart.destroy() }
}

export default BreakdownChart
