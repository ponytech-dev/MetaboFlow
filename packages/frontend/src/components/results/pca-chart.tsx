'use client';

import { useState, useRef } from 'react';
import type { PCAData, PCAPoint } from '@/types/analysis';

interface Tooltip {
  x: number;
  y: number;
  point: PCAPoint;
}

interface PCAChartProps {
  data: PCAData | null;
  width?: number;
  height?: number;
}

const MARGIN = { top: 24, right: 24, bottom: 56, left: 60 };

// Distinct colors for groups
const GROUP_COLORS = [
  '#3b82f6',
  '#ef4444',
  '#22c55e',
  '#f59e0b',
  '#a855f7',
  '#ec4899',
  '#14b8a6',
  '#f97316',
];

export function PCAChart({ data, width = 560, height = 400 }: PCAChartProps) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [tooltip, setTooltip] = useState<Tooltip | null>(null);

  if (!data || data.points.length === 0) {
    return (
      <div
        className="flex items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted-foreground"
        style={{ width, height }}
      >
        No PCA data available.
      </div>
    );
  }

  const innerW = width - MARGIN.left - MARGIN.right;
  const innerH = height - MARGIN.top - MARGIN.bottom;

  // Unique groups
  const groups = Array.from(new Set(data.points.map((p) => p.group)));
  const groupColorMap = Object.fromEntries(
    groups.map((g, i) => [g, GROUP_COLORS[i % GROUP_COLORS.length]])
  );

  // Scale
  const allX = data.points.map((p) => p.pc1);
  const allY = data.points.map((p) => p.pc2);
  const xMin = Math.min(...allX);
  const xMax = Math.max(...allX);
  const yMin = Math.min(...allY);
  const yMax = Math.max(...allY);
  const xPad = (xMax - xMin) * 0.12 + 0.5;
  const yPad = (yMax - yMin) * 0.12 + 0.5;

  const scaleX = (v: number) =>
    ((v - (xMin - xPad)) / (xMax + xPad - (xMin - xPad))) * innerW;
  const scaleY = (v: number) =>
    innerH - ((v - (yMin - yPad)) / (yMax + yPad - (yMin - yPad))) * innerH;

  const xTicks = makeLinearTicks(xMin - xPad, xMax + xPad, 6);
  const yTicks = makeLinearTicks(yMin - yPad, yMax + yPad, 6);

  const [varPC1, varPC2] = data.variance_explained;

  return (
    <div className="relative select-none">
      <svg
        ref={svgRef}
        width={width}
        height={height}
        className="overflow-visible"
        style={{ maxWidth: '100%', height: 'auto' }}
      >
        <g transform={`translate(${MARGIN.left},${MARGIN.top})`}>
          {/* Grid */}
          {yTicks.map((t) => (
            <line
              key={t}
              x1={0}
              x2={innerW}
              y1={scaleY(t)}
              y2={scaleY(t)}
              stroke="currentColor"
              strokeOpacity={0.06}
            />
          ))}
          {xTicks.map((t) => (
            <line
              key={t}
              x1={scaleX(t)}
              x2={scaleX(t)}
              y1={0}
              y2={innerH}
              stroke="currentColor"
              strokeOpacity={0.06}
            />
          ))}

          {/* Zero lines */}
          {xMin - xPad < 0 && xMax + xPad > 0 && (
            <line
              x1={scaleX(0)}
              x2={scaleX(0)}
              y1={0}
              y2={innerH}
              stroke="currentColor"
              strokeOpacity={0.15}
              strokeDasharray="3 3"
            />
          )}
          {yMin - yPad < 0 && yMax + yPad > 0 && (
            <line
              x1={0}
              x2={innerW}
              y1={scaleY(0)}
              y2={scaleY(0)}
              stroke="currentColor"
              strokeOpacity={0.15}
              strokeDasharray="3 3"
            />
          )}

          {/* Points */}
          {data.points.map((pt) => (
            <circle
              key={pt.sample_id}
              cx={scaleX(pt.pc1)}
              cy={scaleY(pt.pc2)}
              r={5}
              fill={groupColorMap[pt.group] ?? '#9ca3af'}
              opacity={0.82}
              stroke="white"
              strokeWidth={1}
              className="cursor-pointer transition-opacity hover:opacity-100"
              onMouseMove={(e) => {
                const svg = svgRef.current;
                if (!svg) return;
                const rect = svg.getBoundingClientRect();
                setTooltip({ x: e.clientX - rect.left, y: e.clientY - rect.top, point: pt });
              }}
              onMouseLeave={() => setTooltip(null)}
            />
          ))}

          {/* X axis */}
          <line x1={0} x2={innerW} y1={innerH} y2={innerH} stroke="currentColor" strokeOpacity={0.2} />
          {xTicks.map((t) => (
            <g key={t} transform={`translate(${scaleX(t)},${innerH})`}>
              <line y2={4} stroke="currentColor" strokeOpacity={0.3} />
              <text y={14} textAnchor="middle" fontSize={10} fill="currentColor" opacity={0.5}>
                {t.toFixed(1)}
              </text>
            </g>
          ))}
          <text
            x={innerW / 2}
            y={innerH + 38}
            textAnchor="middle"
            fontSize={11}
            fill="currentColor"
            opacity={0.6}
          >
            PC1 ({varPC1.toFixed(1)}%)
          </text>

          {/* Y axis */}
          <line x1={0} x2={0} y1={0} y2={innerH} stroke="currentColor" strokeOpacity={0.2} />
          {yTicks.map((t) => (
            <g key={t} transform={`translate(0,${scaleY(t)})`}>
              <line x2={-4} stroke="currentColor" strokeOpacity={0.3} />
              <text
                x={-8}
                textAnchor="end"
                dominantBaseline="middle"
                fontSize={10}
                fill="currentColor"
                opacity={0.5}
              >
                {t.toFixed(1)}
              </text>
            </g>
          ))}
          <text
            transform={`translate(${-46},${innerH / 2}) rotate(-90)`}
            textAnchor="middle"
            fontSize={11}
            fill="currentColor"
            opacity={0.6}
          >
            PC2 ({varPC2.toFixed(1)}%)
          </text>
        </g>

        {/* Legend */}
        <g transform={`translate(${MARGIN.left + 8}, ${MARGIN.top + 8})`}>
          {groups.map((g, i) => (
            <g key={g} transform={`translate(0,${i * 16})`}>
              <circle cx={5} cy={5} r={4.5} fill={groupColorMap[g]} opacity={0.85} />
              <text x={14} y={9} fontSize={10} fill="currentColor" opacity={0.65}>
                {g}
              </text>
            </g>
          ))}
        </g>
      </svg>

      {/* Tooltip */}
      {tooltip && (
        <div
          className="pointer-events-none absolute z-10 rounded-md border border-border bg-popover px-3 py-2 text-xs shadow-lg"
          style={{
            left: tooltip.x + 12,
            top: tooltip.y - 8,
            transform: tooltip.x > width - 180 ? 'translateX(-110%)' : undefined,
          }}
        >
          <p className="font-semibold">{tooltip.point.sample_id}</p>
          <p className="text-muted-foreground">Group: <span className="text-foreground">{tooltip.point.group}</span></p>
          <p className="text-muted-foreground">PC1: <span className="text-foreground font-mono">{tooltip.point.pc1.toFixed(3)}</span></p>
          <p className="text-muted-foreground">PC2: <span className="text-foreground font-mono">{tooltip.point.pc2.toFixed(3)}</span></p>
        </div>
      )}
    </div>
  );
}

function makeLinearTicks(min: number, max: number, count: number): number[] {
  const step = (max - min) / (count - 1);
  return Array.from({ length: count }, (_, i) => Math.round((min + i * step) * 100) / 100);
}
