import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class _ResourceEntry {
  final String name;
  final String description;
  final String link;
  const _ResourceEntry({required this.name, required this.description, required this.link});
}

class _CategoryGroup {
  final String category;
  final List<_ResourceEntry> resources;
  const _CategoryGroup({required this.category, required this.resources});
}

const List<Map<String, dynamic>> _rawData = [
  {
    "category": "Emergency Resources",
    "resources": [
      {
        "name": "911 (Police, Fire, EMS)",
        "description": "Call 9-1-1 for any life-threatening emergency, including heat stroke, fires, or medical distress.",
        "link": "https://www.houstontx.gov/hec/"
      },
      {
        "name": "211 Texas / United Way HELPLINE",
        "description": "Dial 2-1-1 to find nearby cooling centers, shelters, and disaster assistance programs.",
        "link": "https://www.211texas.org/"
      },
      {
        "name": "Houston Office of Emergency Management (OEM)",
        "description": "Provides real-time alerts, emergency plans, and updates during extreme heat events.",
        "link": "https://houstonoem.org/extreme-heat/"
      },
      {
        "name": "ReadyHarris",
        "description": "Harris County’s official preparedness site offering weather alerts, safety tips, and emergency updates.",
        "link": "https://www.readyharris.org/"
      }
    ]
  },
  {
    "category": "Health Resources",
    "resources": [
      {
        "name": "Houston Health Department — Heat Illness Dashboard",
        "description": "Tracks emergency room visits and health trends related to extreme heat across Houston.",
        "link": "https://www.houstonhealth.org/data-dashboards"
      },
      {
        "name": "Harris County Public Health — Climate & Health Program",
        "description": "Provides data, maps, and safety guidance on heat exposure and public health risks.",
        "link": "https://publichealth.harriscountytx.gov/Divisions-Offices/Offices/Office-of-Epidemiology-Surveillance-Emerging-Diseases/Non-Communicable-Diseases/Climate-Program/Extreme-Heat-Health"
      },
      {
        "name": "Houston Emergency Management — Heat Safety Tips",
        "description": "Offers practical tips for recognizing and preventing heat-related illnesses.",
        "link": "https://houstonemergency.org/extreme-heat-tips-to-stay-cool/"
      }
    ]
  },
  {
    "category": "Education",
    "resources": [
      {
        "name": "ReadyHarris — Summer Weather Preparedness",
        "description": "Explains how heat advisories, warnings, and alerts work and what actions to take.",
        "link": "https://www.readyharris.org/prepare-for-summer-weather"
      },
      {
        "name": "University of Houston — Extreme Heat Safety",
        "description": "Provides guidance for students and residents on staying safe before and during extreme heat events.",
        "link": "https://www.uh.edu/emergency-management/be-prepared/extreme-heat/index.php"
      },
      {
        "name": "Coalition for the Homeless — Preparing for Extreme Heat",
        "description": "Details how Houston opens cooling centers and assists those without access to air conditioning.",
        "link": "https://www.cfthhouston.org/preparing-for-extreme-heat-2025"
      }
    ]
  },
  {
    "category": "Utility Assistance",
    "resources": [
      {
        "name": "BakerRipley Utility Assistance Program",
        "description": "Helps eligible households pay electricity, gas, or propane bills during financial hardship.",
        "link": "https://bakerripley.org/programs-and-services/utility-assistance/"
      },
      {
        "name": "Catholic Charities — Financial & Utility Aid",
        "description": "Provides rent and utility assistance for families facing financial emergencies.",
        "link": "https://catholiccharities.org/financial-stability/"
      },
      {
        "name": "Memorial Assistance Ministries (MAM)",
        "description": "Offers emergency financial help to prevent utility shut-offs and housing instability.",
        "link": "https://www.mamhouston.org/"
      }
    ]
  },
  {
    "category": "Volunteer Opportunities",
    "resources": [
      {
        "name": "Volunteer Houston",
        "description": "Search for community projects like water distribution, cooling center staffing, and outreach events.",
        "link": "https://www.volunteerhou.org/"
      },
      {
        "name": "Houston Harris Heat Action Team (H3AT)",
        "description": "Join volunteer efforts to map heat across Houston and raise awareness about heat risk.",
        "link": "https://www.h3at.org/get-involved/"
      },
      {
        "name": "United Way of Greater Houston — Disaster Recovery",
        "description": "Supports volunteer efforts for heat-related and emergency response initiatives.",
        "link": "https://unitedwayhouston.org/what-we-do/disaster-recovery/"
      }
    ]
  },
  {
    "category": "Research & Data",
    "resources": [
      {
        "name": "Houston Health Department — Heat ER Dashboard",
        "description": "Visualizes emergency room visits related to extreme heat by neighborhood and time period.",
        "link": "https://www.houstonhealth.org/data-dashboards"
      },
      {
        "name": "H3AT Mapping Campaign (HARC)",
        "description": "Uses sensors and volunteers to map temperature differences across Houston neighborhoods.",
        "link": "https://harcresearch.org/research/houston-harris-heat-action-team-h3at-mapping-campaign/"
      },
      {
        "name": "Harris County Public Health — Heat Vulnerability Assessment",
        "description": "Identifies neighborhoods most at risk of heat exposure based on social and environmental factors.",
        "link": "https://publichealth.harriscountytx.gov/Divisions-Offices/Offices/Office-of-Epidemiology-Surveillance-Emerging-Diseases/Non-Communicable-Diseases/Climate-Program"
      }
    ]
  }
];

List<_CategoryGroup> _buildGroups() => _rawData.map((c) => _CategoryGroup(
  category: c['category'],
  resources: (c['resources'] as List).map((r) => _ResourceEntry(
    name: r['name'], description: r['description'], link: r['link']
  )).toList(),
)).toList();

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});
  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  static const _dur = Duration(milliseconds: 260);
  late final List<_CategoryGroup> _groups;
  final Map<String,bool> _expanded = {};
  final _search = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _groups = _buildGroups();
    _search.addListener(() => setState(() => _q = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Iterable<_CategoryGroup> _filtered() {
    if (_q.isEmpty) return _groups;
    return _groups.map((g){
      final f = g.resources.where((r)=>
        r.name.toLowerCase().contains(_q) ||
        r.description.toLowerCase().contains(_q)
      ).toList();
      return _CategoryGroup(category: g.category, resources: f);
    }).where((g)=>g.resources.isNotEmpty);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filt = _filtered().toList();
    final total = _groups.fold<int>(0,(p,g)=>p+g.resources.length);
    final shown = filt.fold<int>(0,(p,g)=>p+g.resources.length);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            elevation: 0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[50]!,
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 1.0],
                ),
              ),
            child: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                'Resources',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
            ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _SearchBar(
                  controller: _search,
                  query: _q,
                  onClear: () => _search.clear(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: AnimatedSwitcher(
                    duration: _dur,
                    child: Text(
                      _q.isEmpty
                          ? '$total resources'
                          : '$shown of $total  •  $_q',
                      key: ValueKey('$_q:$shown'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          if (filt.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final g = filt[i];
                  final open = _expanded[g.category] ?? false;
                  return _CategoryCard(
                    group: g,
                    expanded: open,
                    onToggle: () => setState(() {
                      _expanded[g.category] = !open;
                    }),
                    onOpen: _open,
                  );
                },
                childCount: filt.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final VoidCallback onClear;
  const _SearchBar({required this.controller, required this.query, required this.onClear});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[100], 
        border: Border.all(
          color: query.isEmpty
            ? Colors.grey[300]! 
            : Colors.grey[400]!, 
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0,4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: Colors.grey[600]), 
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Search resources...',
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(color: Colors.grey[800]),
              textInputAction: TextInputAction.search,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c,a)=>FadeTransition(opacity:a, child:c),
            child: query.isEmpty
              ? const SizedBox(width: 0)
              : IconButton(
                  key: const ValueKey('clr'),
                  icon: Icon(Icons.close_rounded, 
                      size: 18, 
                      color: Colors.grey[600]), 
                  splashRadius: 18,
                  onPressed: onClear,
                ),
          )
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final _CategoryGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String) onOpen;
  const _CategoryCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

const _kAccentGradient = [Color(0xFF42A5F5), Color(0xFF26C6DA)]; 
const _kCardBgGradient = [Colors.white, Color(0xFFF9FAFB)];      
Color _accentColor(BuildContext c) => Theme.of(c).colorScheme.primary; 

class _CategoryCardState extends State<_CategoryCard>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  @override
  void initState() {
    super.initState();
    @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _c.repeat();
  }
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    if (widget.expanded) _c.value = 1;
  }
  @override
  void didUpdateWidget(covariant _CategoryCard old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) {
      widget.expanded ? _c.forward() : _c.reverse();
    }
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120), 
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(
          color: accent.withOpacity(widget.expanded ? .35 : .20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: widget.expanded ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: widget.onToggle,
              splashColor: accent.withOpacity(.04), 
              highlightColor: accent.withOpacity(.02),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: widget.expanded ? .125 : 0.0, 
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 26,
                          color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.group.category,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          height: 1.1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${widget.group.resources.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: widget.expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          Divider(height: 18, color: Colors.grey[200]), 
                          for (final r in widget.group.resources)
                            _ResourceTile(
                              entry: r,
                              accent: accent,
                              onOpen: widget.onOpen,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceTile extends StatefulWidget {
  final _ResourceEntry entry;
  final Color accent;
  final void Function(String) onOpen;
  const _ResourceTile({required this.entry, required this.accent, required this.onOpen});
  @override
  State<_ResourceTile> createState() => _ResourceTileState();
}

class _ResourceTileState extends State<_ResourceTile> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _down ? .985 : 1), 
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeOutCubic,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onOpen(widget.entry.link);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white, 
            border: Border.all(
              color: accent.withOpacity(_down ? .25 : .15),
              width: 1,
            ),
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(.02), 
                      blurRadius: 6, 
                      offset: const Offset(0, 2), 
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _kAccentGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.link_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.entry.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        height: 1.2,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded,
                      size: 18, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.entry.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.35,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
              size: 70,
              color: t.colorScheme.primary),
            const SizedBox(height: 14),
            Text('No matching resources',
              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Try a different keyword',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              )),
          ],
        ),
      ),
    );
  }
}
